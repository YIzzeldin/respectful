import org.gradle.api.tasks.testing.Test

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    // Flutter plugin packages can ship their own unit tests. Those external
    // suites are not part of this app's contract and can fail under newer JDKs,
    // which makes `gradlew testDebugUnitTest` noisy even when the app tests pass.
    if (project.name != "app" && project.name.endsWith("_android")) {
        tasks.withType<Test>().configureEach {
            enabled = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
