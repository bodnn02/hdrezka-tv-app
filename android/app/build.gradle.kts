import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}
val hasKeystore = keyPropertiesFile.exists()

android {
    namespace = "com.hdrezka.hdrezka_tv"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.hdrezka.hdrezka_tv"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasKeystore) {
                keyAlias      = keyProperties.getProperty("keyAlias")
                keyPassword   = keyProperties.getProperty("keyPassword")
                storeFile     = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
            } else {
                // Fallback to debug keystore when key.properties is absent (CI without secrets)
                val debugStore = file("${System.getProperty("user.home")}/.android/debug.keystore")
                if (debugStore.exists()) storeFile = debugStore
                storePassword = "android"
                keyAlias      = "androiddebugkey"
                keyPassword   = "android"
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
