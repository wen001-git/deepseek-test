import java.util.Properties

// ---------------------------------------------------------------------------
// Release signing — conditional on key.properties existing.
// During development (no key.properties) release falls back to debug signing.
// See android/key.properties.template for setup instructions.
// ---------------------------------------------------------------------------
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.shortvideoai.shortvideoai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.shortvideoai.shortvideoai"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasKeystore) {
                // TODO [RELEASE]: Populate key.properties before Play Store submission.
                // See android/key.properties.template for the required fields.
                storeFile     = file(keystoreProperties["storeFile"]     as String)
                storePassword = keystoreProperties["storePassword"]      as String
                keyAlias      = keystoreProperties["keyAlias"]           as String
                keyPassword   = keystoreProperties["keyPassword"]        as String
            }
            // key.properties absent → block stays empty; release falls back to debug below
        }
    }

    buildTypes {
        release {
            // Uses real release signing when key.properties exists; debug keys otherwise.
            // TODO [RELEASE]: Remove the else branch once keystore is configured.
            signingConfig = if (hasKeystore)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
