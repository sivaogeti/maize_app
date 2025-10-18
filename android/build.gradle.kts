import java.io.File
import org.gradle.api.tasks.Delete
import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.dsl.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val rootBuildDir = File(rootDir.parentFile, "build")
buildDir = rootBuildDir

subprojects {
    buildDir = File(rootDir.parentFile, "build/${project.name}")

    // Ensure all Android modules use a consistent compile/target SDK.
    // Do this after subproject evaluation to override any hardcoded values in plugins.
    afterEvaluate {
        extensions.findByType(ApplicationExtension::class.java)?.let { ext ->
            ext.compileSdk = 36
            ext.defaultConfig { targetSdk = 35 }
        }
        extensions.findByType(LibraryExtension::class.java)?.let { ext ->
            ext.compileSdk = 36
            ext.defaultConfig { targetSdk = 35 }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootBuildDir)
}
