pluginManagement {
    val config = java.util.Properties().apply {
        file("local.properties").inputStream().use { load(it) }
    }
    includeBuild("${config.getProperty("flutter.sdk")}/packages/flutter_tools/gradle")
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
}
include(":app")
