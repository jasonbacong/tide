import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing values live in android/key.properties, which is never committed.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) load(FileInputStream(file))
}

android {
    namespace = "com.jasongrech.tide"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.jasongrech.tide"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        debug {
            // Development builds install as a separate app, so `flutter run` can never
            // replace (and wipe) the real Tide on the phone.
            applicationIdSuffix = ".debug"
        }
        release {
            signingConfig = if (keystoreProperties.isEmpty) signingConfigs.getByName("debug")
                            else signingConfigs.getByName("release")
        }
    }
}

// Never fall back to the debug key silently for a release: a differently-signed build can only
// be installed by uninstalling Tide first, which erases its data. Until android/key.properties
// exists, opt in explicitly with TIDE_ALLOW_DEBUG_SIGNING=1. (Checked only when a release task runs.)
gradle.taskGraph.whenReady {
    val releaseRequested = allTasks.any { task ->
        task.project == project &&
            (task.name.startsWith("assemble") || task.name.startsWith("bundle")) &&
            task.name.contains("Release")
    }
    if (releaseRequested && keystoreProperties.isEmpty &&
        System.getenv("TIDE_ALLOW_DEBUG_SIGNING") != "1"
    ) {
        throw GradleException(
            "android/key.properties is missing. Create it (see M5 plan, Task 10) or set " +
                "TIDE_ALLOW_DEBUG_SIGNING=1 while the phone still has a debug-signed Tide."
        )
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
