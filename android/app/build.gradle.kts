plugins {
    id("com.android.application") version "8.9.1"
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services") // Firebase plugin
}
android {
    namespace = "com.example.my_app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.my_app"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
        }
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlinOptions {
        jvmTarget = "21"
    }

    repositories {
        google()
        mavenCentral()
    }
}

dependencies {
    // Firebase BoM (manages versions for Firebase libraries)
    implementation(platform("com.google.firebase:firebase-bom:34.3.0"))

    // Firebase libraries
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-firestore-ktx")
    implementation("com.google.firebase:firebase-storage-ktx")

    // AndroidX & Material Design
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.11.0")
    implementation("androidx.constraintlayout:constraintlayout:2.2.0")

    // Unit testing
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.6")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
}
// Ensure the google-services plugin is applied at the bottom of the file
apply plugin: 'com.google.gms.google-services'
