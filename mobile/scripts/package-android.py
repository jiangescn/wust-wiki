"""Package local Android APKs with the complete corresponding project source."""
from pathlib import Path
import hashlib
import re
import shutil
import subprocess
import zipfile

root = Path(__file__).resolve().parents[2]
version = re.search(r'^version: ([^+]+)', (root / 'mobile/pubspec.yaml').read_text(encoding='utf-8'), re.M).group(1)
output = root / 'dist/android'
output.mkdir(parents=True, exist_ok=True)
name = 'WUST-Wiki-' + version
built = root / 'mobile/build/app/outputs/flutter-apk'
artifacts = []
for suffix, filename in [('', 'app-release.apk'), ('-arm64-v8a', 'app-arm64-v8a-release.apk'), ('-x86_64', 'app-x86_64-release.apk')]:
    target = output / (name + suffix + '.apk')
    shutil.copyfile(built / filename, target)
    artifacts.append(target)

def repository_files(directory):
    git = ['git', '-c', 'safe.directory=' + str(directory), '-C', str(directory)]
    raw = subprocess.check_output([
        *git, 'ls-files', '--cached', '--others', '--exclude-standard', '-z',
    ])
    ignored = subprocess.run(
        [*git, 'check-ignore', '--no-index', '--stdin', '-z'],
        input=raw,
        stdout=subprocess.PIPE,
    )
    if ignored.returncode not in (0, 1):
        ignored.check_returncode()
    ignored_paths = set(ignored.stdout.split(b'\0'))
    return [
        directory / path.decode('utf-8')
        for path in raw.split(b'\0')
        if path and path not in ignored_paths
    ]

folders = {'app', 'content', 'docs', 'vendor', 'patches', 'licenses', 'mobile', 'scripts', 'server', 'deploy', 'templates', 'tools', 'public'}
root_files = {'README.md', 'AGENTS.md', 'THIRD_PARTY_NOTICES.md', '.gitignore', '.env.example', 'package.json',
              'pnpm-lock.yaml', 'pnpm-workspace.yaml', 'nuxt.config.ts', 'tsconfig.json', 'content.config.ts', 'blog.config.ts'}
files = {path for path in repository_files(root) if path.is_file() and not path.is_symlink()
         and (path.relative_to(root).parts[0] in folders or path.relative_to(root).as_posix() in root_files)}
excluded = {'.git', '.cache', '.data', '.dart_tool', '.gradle', '.kotlin', '.qa', '.nuxt', '.output', 'node_modules',
            '.pnpm-store', '__pycache__', 'build', 'dist', 'generated', 'jniLibs'}
source = output / (name + '-source.zip')
with zipfile.ZipFile(source, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(files):
        relative = path.relative_to(root)
        if excluded.intersection(relative.parts) or path.suffix in {'.log', '.apk', '.aab', '.keystore', '.jks', '.key', '.p12', '.pfx'} or path.name == 'local.properties':
            continue
        if path.name.startswith('.env') and path.name != '.env.example':
            continue
        if path.name == 'slider-location-isolation.png':
            continue  # Live public CAPTCHA image is a diagnosis artifact, not app source.
        archive.write(path, Path('wust-wiki') / relative)
artifacts.append(source)
verification = output / (name + '-verification.md')
shutil.copyfile(root / 'mobile/foundation-integration.md', verification)
artifacts.append(verification)
checksums = []
for path in artifacts:
    checksums.append(hashlib.sha256(path.read_bytes()).hexdigest() + '  ' + path.name)
    print(path.name, path.stat().st_size)
(output / (name + '-SHA256SUMS.txt')).write_text('\n'.join(checksums) + '\n', encoding='utf-8')
