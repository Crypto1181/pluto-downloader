allprojects {
    repositories {
        // Flutter-specific artifacts MUST come first
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
        // Then mirrors
        maven { url = uri("https://maven-central.storage-download.googleapis.com/maven2/") }
        maven { url = uri("https://maven.google.com/") }
        // Fallbacks
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
