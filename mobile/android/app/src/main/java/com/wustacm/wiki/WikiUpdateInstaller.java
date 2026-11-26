package com.wustacm.wiki;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;

import androidx.core.content.FileProvider;

import java.io.File;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import io.flutter.plugin.common.MethodChannel;

final class WikiUpdateInstaller {
    private static final int INSTALL_PERMISSION = 4301;
    private final Activity activity;
    private final SharedPreferences prefs;
    private final File directory;
    private MethodChannel.Result permissionResult;

    WikiUpdateInstaller(Activity activity) {
        this.activity = activity;
        prefs = activity.getSharedPreferences("wiki-updates", Activity.MODE_PRIVATE);
        directory = new File(activity.getCacheDir(), "wiki-updates");
    }

    void info(MethodChannel.Result result) {
        try {
            PackageInfo installed = installedPackage();
            long now = System.currentTimeMillis();
            long lastChecked = prefs.getLong("lastChecked", 0);
            Map<String, Object> values = new HashMap<>();
            values.put("versionName", installed.versionName);
            values.put("versionCode", versionCode(installed));
            values.put("signerSha256", signerSha256(installed));
            values.put("packageName", activity.getPackageName());
            values.put("cacheDirectory", directory.getAbsolutePath());
            values.put("abis", Arrays.asList(Build.SUPPORTED_ABIS));
            values.put("sdk", Build.VERSION.SDK_INT);
            values.put("autoCheckDue", lastChecked > now || now - lastChecked >= TimeUnit.DAYS.toMillis(1));
            result.success(values);
        } catch (PackageManager.NameNotFoundException error) {
            result.error("update_info_unavailable", null, null);
        }
    }

    private static String signerSha256(PackageInfo info) {
        Signature[] signatures = signers(info);
        if (signatures.length != 1) return "";
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(signatures[0].toByteArray());
            StringBuilder hex = new StringBuilder(digest.length * 2);
            for (byte value : digest) {
                hex.append(Character.forDigit((value >>> 4) & 15, 16));
                hex.append(Character.forDigit(value & 15, 16));
            }
            return hex.toString();
        } catch (NoSuchAlgorithmException error) {
            throw new IllegalStateException(error);
        }
    }

    void recordCheck() {
        prefs.edit().putLong("lastChecked", System.currentTimeMillis()).apply();
    }

    void install(Number expectedVersion, boolean openSettings, MethodChannel.Result result) {
        if (expectedVersion == null || permissionResult != null) {
            result.success("failed");
            return;
        }
        File apk = new File(directory, "wiki-update.apk");
        new Thread(() -> {
            boolean valid = validate(apk, expectedVersion.longValue());
            activity.runOnUiThread(() -> {
                if (activity.isDestroyed()) {
                    result.success("failed");
                } else if (!valid) {
                    result.success("invalidPackage");
                } else if (canInstall()) {
                    openInstaller(apk, result);
                } else if (openSettings) {
                    requestPermission(result);
                } else {
                    result.success("permission");
                }
            });
        }, "wiki-update-verify").start();
    }

    private PackageInfo installedPackage() throws PackageManager.NameNotFoundException {
        return activity.getPackageManager().getPackageInfo(activity.getPackageName(), signingFlags());
    }

    private boolean validate(File apk, long expectedVersion) {
        if (!apk.isFile()) return false;
        try {
            PackageInfo installed = installedPackage();
            PackageInfo candidate = activity.getPackageManager().getPackageArchiveInfo(
                apk.getAbsolutePath(), signingFlags()
            );
            if (candidate == null || !installed.packageName.equals(candidate.packageName)
                || versionCode(candidate) != expectedVersion || expectedVersion <= versionCode(installed)) {
                return false;
            }
            Signature[] current = signers(installed);
            Signature[] incoming = signers(candidate);
            return current.length > 0 && new HashSet<>(Arrays.asList(current))
                .equals(new HashSet<>(Arrays.asList(incoming)));
        } catch (PackageManager.NameNotFoundException | RuntimeException error) {
            return false;
        }
    }

    @SuppressWarnings("deprecation")
    private static int signingFlags() {
        return Build.VERSION.SDK_INT >= 28
            ? PackageManager.GET_SIGNING_CERTIFICATES : PackageManager.GET_SIGNATURES;
    }

    @SuppressWarnings("deprecation")
    private static Signature[] signers(PackageInfo info) {
        if (Build.VERSION.SDK_INT >= 28) {
            return info.signingInfo == null ? new Signature[0] : info.signingInfo.getApkContentsSigners();
        }
        return info.signatures == null ? new Signature[0] : info.signatures;
    }

    @SuppressWarnings("deprecation")
    private static long versionCode(PackageInfo info) {
        return Build.VERSION.SDK_INT >= 28 ? info.getLongVersionCode() : info.versionCode;
    }

    private boolean canInstall() {
        return Build.VERSION.SDK_INT < 26 || activity.getPackageManager().canRequestPackageInstalls();
    }

    private void requestPermission(MethodChannel.Result result) {
        try {
            Intent intent = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.fromParts("package", activity.getPackageName(), null));
            permissionResult = result;
            activity.startActivityForResult(intent, INSTALL_PERMISSION);
        } catch (ActivityNotFoundException | SecurityException error) {
            permissionResult = null;
            result.success("failed");
        }
    }

    boolean onActivityResult(int requestCode) {
        if (requestCode != INSTALL_PERMISSION) return false;
        MethodChannel.Result result = permissionResult;
        permissionResult = null;
        if (result != null) {
            if (canInstall()) {
                openInstaller(new File(directory, "wiki-update.apk"), result);
            } else {
                result.success("permission");
            }
        }
        return true;
    }

    private void openInstaller(File apk, MethodChannel.Result result) {
        try {
            Uri uri = FileProvider.getUriForFile(activity, activity.getPackageName() + ".updates", apk);
            Intent intent = new Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            activity.startActivity(intent);
            result.success("opened");
        } catch (ActivityNotFoundException | SecurityException | IllegalArgumentException error) {
            result.success("failed");
        }
    }
}
