import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val uploadKeyPropertiesFile = rootProject.file("key.properties")
val uploadKeyProperties = Properties().apply {
    if (uploadKeyPropertiesFile.exists()) {
        uploadKeyPropertiesFile.inputStream().use { load(it) }
    }
}

fun uploadKeyProperty(name: String): String =
    requireNotNull(uploadKeyProperties.getProperty(name)?.takeIf { it.isNotBlank() }) {
        "Missing signing property '$name' in android/key.properties"
    }

android {
    namespace = "io.github.dferrandizmont.carrete"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "es.diapo.app"
        minSdk = 26
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (uploadKeyPropertiesFile.exists()) {
            create("release") {
                storeFile = file(uploadKeyProperty("storeFile"))
                storePassword = uploadKeyProperty("storePassword")
                keyAlias = uploadKeyProperty("keyAlias")
                keyPassword = uploadKeyProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (uploadKeyPropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "android/key.properties is absent: release uses the debug key " +
                        "for private prereleases. Configure the upload key before uploading to Play."
                )
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    testOptions {
        // ExifInterface logs through android.util.Log: let the stubs answer
        // instead of throwing, so the JVM tests can run it on a real file.
        unitTests.isReturnDefaultValues = true
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

// A store upload must never be signed with the debug key: the bundle task
// needs the upload key, while release APKs keep the debug fallback for the
// private prereleases.
tasks.matching { it.name == "bundleRelease" }.configureEach {
    doFirst {
        if (!uploadKeyPropertiesFile.exists()) {
            throw GradleException("android/key.properties is required for bundleRelease")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.core:core:1.18.0")
    implementation("androidx.exifinterface:exifinterface:1.3.7")
    testImplementation("junit:junit:4.13.2")
}
