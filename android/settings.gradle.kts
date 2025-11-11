pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    // Try to avoid Gradle Plugin Portal for Kotlin/Android plugins to mitigate TLS issues
    resolutionStrategy {
        eachPlugin {
            when (requested.id.id) {
                // Map Kotlin plugins to Maven Central artifact instead of Plugin Portal
                "org.jetbrains.kotlin.jvm",
                "org.jetbrains.kotlin.android",
                "org.jetbrains.kotlin.kapt",
                "org.jetbrains.kotlin.multiplatform" -> {
                    useModule("org.jetbrains.kotlin:kotlin-gradle-plugin:${requested.version}")
                }
                // Map Android Gradle plugin ids directly to Google Maven artifact
                "com.android.application",
                "com.android.library",
                "com.android.test",
                "com.android.dynamic-feature" -> {
                    useModule("com.android.tools.build:gradle:${requested.version}")
                }
            }
        }
    }

    repositories {
        // Prefer mirrors first to avoid flaky endpoints
        maven("https://maven-central.storage-download.googleapis.com/maven2/")
        maven("https://maven.google.com/")
        // Fallbacks
        google()
        mavenCentral()
        gradlePluginPortal()
        maven { url = uri("https://jitpack.io") }
        maven { url = uri("https://repo1.maven.org/maven2/") }
    }
}

// Ensure all projects use these repositories (mirrors first)
dependencyResolutionManagement {
    repositories {
        maven("https://storage.googleapis.com/download.flutter.io")
        maven("https://maven-central.storage-download.googleapis.com/maven2/")
        maven("https://maven.google.com/")
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
        maven { url = uri("https://repo1.maven.org/maven2/") }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
