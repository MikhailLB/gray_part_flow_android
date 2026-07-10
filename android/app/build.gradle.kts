import java.util.Properties
import java.io.FileInputStream

// ============================================================
// Android app module — gray-part-flow template
// ============================================================
// [TODO] Per new project change BOTH `namespace` and `applicationId`
//         to your fresh package id. They must be identical to:
//           • lib/env/facade.dart → packageId + marketId
//           • android/app/google-services.json → package_name
//           • android/app/src/main/kotlin/**/MainActivity.kt package
//         See android_gray_guide.md §"Setup Checklist" Step 1.
//
// [FINGERPRINT] Do not reuse the previous project's applicationId or
// its Kotlin source folder path. See the Kotlin package rename step
// documented in the root `START_HERE.md`.
// ============================================================

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and
    // Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Apply the Google Services plugin only once google-services.json is
// present. This lets the template build before Firebase credentials
// are supplied (config gate will just fall back to the native game).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Load release signing config from android/key.properties if present.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // Internal namespace (R class / source package). The published
    // Application ID is set via `applicationId` below.
    //
    // [TODO] Replace with your project package. Must match the Kotlin
    // source folder path under android/app/src/main/kotlin/.
    namespace = "com.example.template"

    // Per TZ §6 — targetSdk = 35, minSdk = 26 (Android 8.0), compileSdk stays
    // at 36 for plugin compatibility (see gray_part_pitfalls.md §2).
    //
    // ⚠️ AI AGENT: keep minSdk at the LOWEST value that the current Firebase +
    // AppsFlyer + flutter_local_notifications stack still supports. As of the
    // versions pinned in pubspec.yaml that floor is API 26 (Android 8.0).
    // Do NOT raise minSdk higher unless a dependency literally refuses to build
    // — every extra API level slices off eligible users from the campaign.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications 18+ (java.time.*).
        // See gray_part_pitfalls.md §5.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // [TODO] Replace with your project applicationId. See header.
        applicationId = "com.example.template"
        // Android 8.0 (Oreo) — lowest API supported by the current
        // Firebase/AppsFlyer stack. See compileSdk comment above.
        minSdk = 26
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
