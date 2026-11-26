"""Stage signed APKs and publish the Android update feed to R2."""

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ABIS = ("arm64-v8a", "x86_64")
PACKAGE_NAME = "com.wustacm.wiki"
PUBLIC_BASE = "https://download.wust.club/wiki"
LATEST_KEY = "wiki/latest.json"


def run(*args):
    return subprocess.run(args, text=True, encoding="utf-8", capture_output=True)


def checked(*args):
    result = run(*args)
    if result.returncode:
        raise ValueError(result.stderr.strip() or result.stdout.strip())
    return result.stdout


def stage(args):
    tag = re.fullmatch(r"android-v([0-9]+\.[0-9]+\.[0-9]+)", args.tag)
    if not tag:
        raise ValueError("Expected an android-vX.Y.Z tag.")
    version = tag[1]
    notes = args.notes.read_text(encoding="utf-8").strip()
    if not 0 < len(notes) <= 6000:
        raise ValueError("Provide release notes of up to 6000 characters.")
    args.output.mkdir(parents=True, exist_ok=True)
    manifest = {
        "schemaVersion": 1,
        "packageName": PACKAGE_NAME,
        "versionName": version,
        "notes": notes,
        "artifacts": {},
    }
    for abi in ABIS:
        apk = args.apk_dir / f"app-{abi}-release.apk"
        badging = checked(args.aapt, "dump", "badging", str(apk))
        identity = re.search(
            r"^package: name='([^']+)' versionCode='([0-9]+)' versionName='([^']+)'",
            badging,
            re.M,
        )
        abi_line = re.search(r"^native-code: '([^']+)'\s*$", badging, re.M)
        min_sdk = re.search(r"^sdkVersion:'([0-9]+)'", badging, re.M)
        if not identity or identity[1] != PACKAGE_NAME or identity[3] != version:
            raise ValueError(f"APK identity does not match tag {args.tag}: {apk.name}")
        if not abi_line or abi_line[1] != abi or not min_sdk:
            raise ValueError(f"APK architecture or minimum SDK mismatch: {apk.name}")
        certificate = checked(args.apksigner, "verify", "--print-certs", str(apk))
        signers = re.findall(r"^Signer #\d+ certificate SHA-256 digest: ([a-f0-9]{64})\s*$", certificate, re.M)
        if len(signers) != 1 or ("CN=Android Debug" in certificate and not args.allow_debug):
            raise ValueError(f"APK requires a single release signing certificate: {apk.name}")
        if manifest.setdefault("signerSha256", signers[0]) != signers[0]:
            raise ValueError("The architecture builds must share the same signing certificate.")
        name = f"WUST-Wiki-{version}-{abi}.apk"
        with apk.open("rb") as file:
            digest = hashlib.file_digest(file, "sha256").hexdigest()
        manifest["artifacts"][abi] = {
            "versionCode": int(identity[2]),
            "minSdk": int(min_sdk[1]),
            "size": apk.stat().st_size,
            "url": f"{PUBLIC_BASE}/{version}/{name}",
            "sha256": digest,
        }
        shutil.copyfile(apk, args.output / name)
    (args.output / "latest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Staged Android {version} for {', '.join(ABIS)}.")


def download_public(url, destination):
    fetcher = Path(__file__).with_name("download-update.dart")
    result = subprocess.run(
        ["dart", str(fetcher), url, str(destination)],
        text=True, encoding="utf-8", capture_output=True, timeout=240,
    )
    if result.returncode:
        raise ValueError(result.stderr.strip() or f"Could not download {url}.")


def verify_apk(artifact):
    with tempfile.TemporaryDirectory() as tmp:
        local = Path(tmp) / "release.apk"
        url = artifact["url"]
        download_public(url, local)
        if local.stat().st_size != artifact["size"]:
            raise ValueError(f"Wrong public download size at {url}.")
        with local.open("rb") as file:
            digest = hashlib.file_digest(file, "sha256").hexdigest()
        if digest != artifact["sha256"]:
            raise ValueError(f"Wrong public download checksum at {url}.")
        print(f"Verified public download {url}.")


def verify_manifest(manifest):
    with tempfile.TemporaryDirectory() as tmp:
        remote = Path(tmp) / "latest.json"
        download_public(f"{PUBLIC_BASE}/latest.json", remote)
        if json.loads(remote.read_text(encoding="utf-8")) != manifest:
            raise ValueError("Public update feed does not match this release.")


def verify(args):
    manifest = json.loads((args.release / "latest.json").read_text(encoding="utf-8"))
    verify_manifest(manifest)
    for abi in ABIS:
        verify_apk(manifest["artifacts"][abi])
    print(f"Verified Android {manifest['versionName']} on R2.")


def publish(args):
    manifest_path = args.release / "latest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    version = manifest["versionName"]
    s3 = ("aws", "--endpoint-url", args.endpoint, "s3api")
    with tempfile.TemporaryDirectory() as tmp:
        old_path = Path(tmp) / "latest.json"
        current = run(*s3, "get-object", "--bucket", args.bucket, "--key", LATEST_KEY, str(old_path))
        if current.returncode == 0:
            etag = json.loads(current.stdout)["ETag"]
            old = json.loads(old_path.read_text(encoding="utf-8"))
            if old != manifest and (
                old["signerSha256"] != manifest["signerSha256"]
                or any(
                    manifest["artifacts"][abi]["versionCode"] <= old["artifacts"][abi]["versionCode"]
                    for abi in ABIS
                )
            ):
                raise ValueError("Use the existing signing certificate and higher version codes for every APK.")
            condition = ("--if-match", etag)
        elif "(NoSuchKey)" in current.stderr or "(404)" in current.stderr:
            condition = ("--if-none-match", "*")
        else:
            raise ValueError(current.stderr.strip() or "Could not read the current update feed.")

    for abi in ABIS:
        artifact = manifest["artifacts"][abi]
        name = f"WUST-Wiki-{version}-{abi}.apk"
        upload = run(
            *s3, "put-object", "--bucket", args.bucket, "--key", f"wiki/{version}/{name}",
            "--body", str(args.release / name), "--content-type", "application/vnd.android.package-archive",
            "--cache-control", "public, max-age=31536000, immutable", "--if-none-match", "*",
        )
        if upload.returncode and "(PreconditionFailed)" not in upload.stderr and "(412)" not in upload.stderr:
            raise ValueError(upload.stderr.strip() or f"Could not upload {name}.")
        verify_apk(artifact)

    checked(
        *s3, "put-object", "--bucket", args.bucket, "--key", LATEST_KEY, "--body", str(manifest_path),
        "--content-type", "application/json; charset=utf-8", "--cache-control", "no-store", *condition,
    )
    verify_manifest(manifest)
    print(f"Published Android {version}.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    staging = commands.add_parser("stage")
    staging.add_argument("--apk-dir", type=Path, required=True)
    staging.add_argument("--output", type=Path, required=True)
    staging.add_argument("--notes", type=Path, required=True)
    staging.add_argument("--tag", required=True)
    staging.add_argument("--aapt", required=True)
    staging.add_argument("--apksigner", required=True)
    staging.add_argument("--allow-debug", action="store_true", help="Stage a local test fixture.")
    publication = commands.add_parser("publish")
    publication.add_argument("--release", type=Path, required=True)
    publication.add_argument("--bucket", required=True)
    publication.add_argument("--endpoint", required=True)
    verification = commands.add_parser("verify")
    verification.add_argument("--release", type=Path, required=True)
    args = parser.parse_args()
    try:
        {"stage": stage, "publish": publish, "verify": verify}[args.command](args)
    except (ValueError, OSError, KeyError, subprocess.TimeoutExpired) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
