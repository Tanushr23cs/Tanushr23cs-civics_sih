// Root-level build.gradle.kts

plugins {
    // Optional: no need to apply google-services here, just make it available for modules
    id("com.google.gms.google-services") version "4.4.3" apply false
}

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
    classpath 'com.android.tools.build:gradle:7.4.2'
    classpath 'com.google.gms:google-services:4.4.3' // example
}

}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Custom build directory setup
val newBuildDir: Directory =
    rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Ensure app module is evaluated first
subprojects {
    project.evaluationDependsOn(":app")
}

// Clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
