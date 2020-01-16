import com.jfrog.bintray.gradle.BintrayExtension
import groovy.util.Node
import groovy.util.NodeList
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.jlleitschuh.gradle.ktlint.KtlintExtension
import org.jlleitschuh.gradle.ktlint.reporter.ReporterType
import com.github.jengelman.gradle.plugins.shadow.tasks.ShadowJar

plugins {
    kotlin("jvm") version "1.3.21"
    id("org.jlleitschuh.gradle.ktlint") version "7.1.0"
    id("com.star-zero.gradle.githook") version "1.1.0"
    id("com.jfrog.bintray") version "1.8.4"
    id("com.github.johnrengelman.shadow") version "4.0.4"
    id("com.moowork.node") version "1.3.1"
    `maven-publish`
}

fun version(): String {
    val buildNumber = System.getProperty("BUILD_NUM")
    val version = "1.1" + if (buildNumber.isNullOrEmpty()) "-SNAPSHOT" else ".$buildNumber"
    println("building version $version")
    return version
}

val projectVersion = version()

group = "io.hexlabs"
val artifactId = "kloudformation-runner"
version = projectVersion

repositories {
    jcenter()
    mavenCentral()
    maven("https://dl.bintray.com/hexlabsio/kloudformation")
}

dependencies {
    implementation(kotlin("stdlib-jdk8"))
    implementation("software.amazon.awssdk:cloudformation:2.5.23")
    implementation("software.amazon.awssdk:s3:2.5.23")
    implementation("software.amazon.awssdk:lambda:2.5.23")
    runtime("org.slf4j:slf4j-simple:1.7.25")
    testImplementation("io.kloudformation:kloudformation:1.1.149")
    testImplementation("io.hexlabs:kloudformation-s3-module:1.1.12")
    testImplementation(group = "org.jetbrains.kotlin", name = "kotlin-test-junit5", version = "1.3.21")
    testImplementation(group = "org.junit.jupiter", name = "junit-jupiter-api", version = "1.3.21")
    testRuntime(group = "org.junit.jupiter", name = "junit-jupiter-engine", version = "5.0.0")
}

sourceSets {
    main {
        java {
            srcDirs("src/main/kotlin")
        }
    }
    test {
        java {
            srcDirs("src/test/kotlin", "stack")
        }
    }
}


val shadowJar by tasks.getting(ShadowJar::class) {
    archiveClassifier.set("uber")
    manifest {
        attributes(mapOf("Main-Class" to "io.hexlabs.kloudformation.runner.DeployKt"))
    }
}

val sourcesJar by tasks.creating(Jar::class) {
    archiveClassifier.set("sources")
    from(sourceSets["main"].allSource)
}

val compile = tasks.withType<KotlinCompile> {
    kotlinOptions.jvmTarget = "1.8"
    finalizedBy(shadowJar)
}
tasks.withType<Test> {
    useJUnitPlatform()
}

configure<KtlintExtension> {
    outputToConsole.set(true)
    coloredOutput.set(true)
    reporters.set(setOf(ReporterType.CHECKSTYLE, ReporterType.JSON))
}



artifacts {
    add("archives", shadowJar)
    add("archives", sourcesJar)
}

bintray {
    user = "chrisbarbour"
    key = System.getProperty("BINTRAY_KEY") ?: "UNKNOWN"
    setPublications("mavenJava")
    publish = true
    pkg(
        closureOf<BintrayExtension.PackageConfig> {
            repo = "kloudformation"
            name = artifactId
            userOrg = "hexlabsio"
            setLicenses("Apache-2.0")
            vcsUrl = "https://github.com/hexlabsio/kloudformation-runner.git"
            version(closureOf<BintrayExtension.VersionConfig> {
                name = projectVersion
                desc = projectVersion
            })
        })
}

publishing {
    publications {
        register("mavenJava", MavenPublication::class) {
            from(components["java"])
            artifactId = artifactId
            artifact(sourcesJar)
            artifact(shadowJar)
            pom.withXml {
                val dependencies = (asNode()["dependencies"] as NodeList)
                configurations.compile.get().allDependencies.forEach {
                    dependencies.add(Node(null, "dependency").apply {
                        appendNode("groupId", it.group)
                        appendNode("artifactId", it.name)
                        appendNode("version", it.version)
                    })
                }
            }
        }
    }
}