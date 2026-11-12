plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/**
 * Release signing. The private keystore lives outside the repository: its path and
 * passwords come from ~/.gradle/gradle.properties locally, or ORG_GRADLE_PROJECT_*
 * environment variables in CI. See "Releases" in the README.
 */
val releaseSigningProperties = listOf(
    "CUMBIONSITO_UPLOAD_STORE_FILE",
    "CUMBIONSITO_UPLOAD_KEY_ALIAS",
    "CUMBIONSITO_UPLOAD_STORE_PASSWORD",
    "CUMBIONSITO_UPLOAD_KEY_PASSWORD",
)
val hasReleaseSigning = releaseSigningProperties.all { project.hasProperty(it) }

gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any {
        it.project == project && it.name.matches(Regex("(assemble|bundle|package)Release"))
    }
    if (buildsRelease && !hasReleaseSigning) {
        throw GradleException(
            "Release builds need the private signing key. Set " +
                releaseSigningProperties.joinToString(", ") +
                " in ~/.gradle/gradle.properties (see the README)."
        )
    }
}

android {
    namespace = "com.dansecan25.cumbionsito"
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
        applicationId = "com.dansecan25.cumbionsito"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Both come from "version" in pubspec.yaml.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(project.property("CUMBIONSITO_UPLOAD_STORE_FILE") as String)
                storePassword = project.property("CUMBIONSITO_UPLOAD_STORE_PASSWORD") as String
                keyAlias = project.property("CUMBIONSITO_UPLOAD_KEY_ALIAS") as String
                keyPassword = project.property("CUMBIONSITO_UPLOAD_KEY_PASSWORD") as String
            }
        }
    }

    buildTypes {
        release {
            // Updates only install over an app signed with the same key, so release
            // builds never fall back to the public debug key.
            signingConfig = if (hasReleaseSigning) signingConfigs.getByName("release") else null
        }
    }
}

dependencies {
    // FileProvider, used to hand downloaded updates to the package installer.
    implementation("androidx.core:core-ktx:1.18.0") // 1.19+ needs compileSdk 37 and AGP 9
}

flutter {
    source = "../.."
}
