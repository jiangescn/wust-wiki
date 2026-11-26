plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}
val releaseSigning = listOf(
    "ANDROID_KEYSTORE_PATH",
    "ANDROID_STORE_PASSWORD",
    "ANDROID_KEY_ALIAS",
    "ANDROID_KEY_PASSWORD",
).associateWith { System.getenv(it)?.takeIf(String::isNotBlank) }
val hasReleaseSigning = releaseSigning.values.any { it != null }
if (hasReleaseSigning) {
    require(releaseSigning.values.all { it != null }) { "Android release signing requires all four settings." }
}

android {
    namespace = "com.wustacm.wiki"
    compileSdk = 36
    ndkVersion = "28.2.13676358"
    defaultConfig {
        applicationId = "com.wustacm.wiki"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    signingConfigs {
        if (hasReleaseSigning) {
            create("wikiRelease") {
                storeFile = file(releaseSigning.getValue("ANDROID_KEYSTORE_PATH")!!)
                storePassword = releaseSigning.getValue("ANDROID_STORE_PASSWORD")
                keyAlias = releaseSigning.getValue("ANDROID_KEY_ALIAS")
                keyPassword = releaseSigning.getValue("ANDROID_KEY_PASSWORD")
            }
        }
    }
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName(if (hasReleaseSigning) "wikiRelease" else "debug")
        }
    }
    packaging { jniLibs {
        useLegacyPackaging = true
        keepDebugSymbols.add("**/*.so")
        excludes.add("**/armeabi-v7a/**")
        excludes.add("**/x86/**")
    } }
}
flutter { source = "../.." }
dependencies {
    implementation("com.google.zxing:core:3.5.3")
    implementation("com.google.mlkit:text-recognition:16.0.1")
}
