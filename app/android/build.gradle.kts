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

// The printing Android plugin pins compileSdk 34. Use the application's
// compatible installed API level instead of downloading an older SDK package.
subprojects {
    if (name == "printing") {
        val useInstalledCompileSdk = {
            extensions.findByName("android")?.let { androidExtension ->
                val setter = androidExtension.javaClass.methods.firstOrNull {
                    it.name in setOf("setCompileSdk", "setCompileSdkVersion") &&
                        it.parameterCount == 1 &&
                        it.parameterTypes[0] == Int::class.java
                } ?: throw GradleException("Installed Android library compile SDK could not be selected.")
                setter.invoke(androidExtension, 35)
            }
        }
        if (state.executed) {
            useInstalledCompileSdk()
        } else {
            afterEvaluate { useInstalledCompileSdk() }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
