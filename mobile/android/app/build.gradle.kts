import java.util.Properties
import org.gradle.api.GradleException

// ---------------------------------------------------------------------------
// Release signing — release builds must use a real upload key.
// See android/key.properties.template for setup instructions.
// ---------------------------------------------------------------------------
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeystore = keystorePropertiesFile.exists()
val isReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (hasKeystore) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
} else if (isReleaseBuild) {
    throw GradleException(
        "Release signing requires android/key.properties. " +
            "Copy android/key.properties.template to android/key.properties " +
            "and fill in your real keystore credentials before building a release."
    )
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
                storeFile     = file(keystoreProperties["storeFile"]     as String)
                storePassword = keystoreProperties["storePassword"]      as String
                keyAlias      = keystoreProperties["keyAlias"]           as String
                keyPassword   = keystoreProperties["keyPassword"]        as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
