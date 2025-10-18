import java.util.Properties
import java.io.FileInputStream

val localProps = Properties().apply {
    val f = File(rootProject.projectDir, "local.properties")
    if (f.exists()) FileInputStream(f).use { load(it) }
}

val flutterVersionCode = (localProps.getProperty("flutter.versionCode") ?: "1").toInt()
val flutterVersionName = localProps.getProperty("flutter.versionName") ?: "1.0"

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.maizemate_app"

    // You can hardcode, or omit and let Flutter’s plugin set these.
    compileSdk = 35

    ndkVersion = "26.1.10909125"

    defaultConfig {
        applicationId = "com.example.maizemate_app"
        minSdk = 24
        targetSdk = 35
        versionCode = flutterVersionCode
        versionName = flutterVersionName

        // ✅ DO NOT add ndk { abiFilters ... } here
        // ✅ DO NOT add splits { abi { ... } } here
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            // Read android/key.properties
            val props = Properties()
            val propsFile = File(rootProject.projectDir, "key.properties")
            if (propsFile.exists()) {
                FileInputStream(propsFile).use { fis ->
                    props.load(fis)
                }
                keyAlias = props["keyAlias"] as String
                keyPassword = props["keyPassword"] as String
                storePassword = props["storePassword"] as String
                storeFile = file(props["storeFile"] as String) // ../my-release-key.jks
            } else {
                throw GradleException("Missing key.properties at: ${propsFile.absolutePath}")
            }
            enableV1Signing = true
            enableV2Signing = true
        }
    }


    buildTypes {
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        maybeCreate("profile")
        getByName("profile") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }
    }


    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions { jvmTarget = "17" }

    // No splits/packaging tweaks needed for ABIs
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.3")
    implementation("androidx.multidex:multidex:2.0.1")
}
