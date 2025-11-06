plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.cardguess"
    compileSdk = flutter.compileSdkVersion


    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.cardguess"
        // ✅ Firebase requires minSdk 23+
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // For now, use debug keystore — replace with your signing config for production
            signingConfig = signingConfigs.getByName("debug")

            minifyEnabled false
            shrinkResources false
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    packagingOptions {

        resources {
            excludes += [
                "META-INF/AL2.0",
                "META-INF/LGPL2.1"
            ]
        }
    }
}

flutter {
    source = "../.."
}

apply plugin: 'com.google.gms.google-services'
