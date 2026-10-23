// Tracked Android app configuration; keep the applicationId in sync with
// Google Cloud OAuth client "Simple Notes Android" (package + signing SHA-1).
// Do not add a top-level kotlin { compilerOptions { ... } } block: the
// generated AGP 9 setup may use built-in Kotlin and does not expose it.
plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "it.andreadada.simplenotes"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "it.andreadada.simplenotes"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TEMPORARY: debug signing to permit local smoke tests only.
            // Before a production release, configure separate secure release signing.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
