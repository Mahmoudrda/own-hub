import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing, read from a file that is never committed.
//
// `android/key.properties` is produced by `keytool` (see docs/release/). When it
// is ABSENT a release build FAILS, loudly, instead of signing with the debug
// key: a debug-signed release cannot be uploaded to Play and must never be
// passed around as if it were the real app. Debug builds and tests are not
// affected. For a local QA build that will never be uploaded, opt in to debug
// signing explicitly with OWNHUB_ALLOW_DEBUG_SIGNING=1 (environment) or
// -PallowDebugSigning=true. `tool/release_preflight.sh` also fails without the
// real key.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val allowDebugSigning =
    providers.environmentVariable("OWNHUB_ALLOW_DEBUG_SIGNING").orNull == "1" ||
        project.findProperty("allowDebugSigning") == "true"

gradle.taskGraph.whenReady {
    if (!hasReleaseKeystore && !allowDebugSigning &&
        allTasks.any { it.name.contains("Release") }
    ) {
        throw GradleException(
            "android/key.properties is missing: refusing to build a release signed " +
                "with the debug key. Set OWNHUB_ALLOW_DEBUG_SIGNING=1 only for a local " +
                "QA build that will never be uploaded.",
        )
    }
}

android {
    namespace = "com.ownhub.app"

    // Pinned explicitly, not inherited from the Flutter defaults: Google Play
    // requires new apps and updates to target Android 16 (API 36) since
    // 31 August 2026, and a silently-moving default is how that requirement is
    // missed the month the toolchain changes.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (training reminders) schedules with
        // java.time, which needs desugaring below Android 8.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.ownhub.app"
        // Android 7.0. Lower adds test surface for a vanishing share of handsets.
        minSdk = 24
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else if (allowDebugSigning) {
                signingConfigs.getByName("debug")
            } else {
                null
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
