// Tracked Android app configuration; keep the applicationId in sync with
// Google Cloud OAuth client "Simple Notes Android" (package + signing SHA-1).
// Do not add a top-level kotlin { compilerOptions { ... } } block: the
// generated AGP 9 setup may use built-in Kotlin and does not expose it.
plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Java-only Flutter launcher: leave AGP built-in Kotlin disabled when
    // possible. Some Flutter/plugin versions still register a Kotlin task.
    enableKotlin = false
    namespace = "it.andreadada.simplenotes"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Flutter/Gradle runs with JDK 17 or 21 depending on the developer
    // machine. Kotlin's task defaults to that JVM, too. Keep Java bytecode
    // compatibility aligned with the actual Gradle JDK so KGP's strict JVM
    // target validation never sees Java 17 vs Kotlin 21. CI builds both.
    compileOptions {
        sourceCompatibility = JavaVersion.current()
        targetCompatibility = JavaVersion.current()
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
