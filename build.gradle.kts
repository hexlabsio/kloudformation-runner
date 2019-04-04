import com.jfrog.bintray.gradle.BintrayExtension
import com.star_zero.gradle.githook.GithookExtension
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
    `maven-publish`
}

fun version(): String {
    val buildNumber = System.getProperty("BUILD_NUM")
    val version = "0.1" + if (buildNumber.isNullOrEmpty()) "-SNAPSHOT" else ".$buildNumber"
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
}

dependencies {
    implementation(kotlin("stdlib-jdk8"))
    implementation("software.amazon.awssdk:cloudformation:2.5.23")
    runtime("org.slf4j:slf4j-simple:1.7.25")
    testImplementation(group = "org.jetbrains.kotlin", name = "kotlin-test-junit5", version = "1.3.21")
    testImplementation(group = "org.junit.jupiter", name = "junit-jupiter-api", version = "1.3.21")
    testRuntime(group = "org.junit.jupiter", name = "junit-jupiter-engine", version = "5.0.0")
}

tasks.withType<KotlinCompile> {
    kotlinOptions.jvmTarget = "1.8"
}
tasks.withType<Test> {
    useJUnitPlatform()
}

configure<KtlintExtension> {
    outputToConsole.set(true)
    coloredOutput.set(true)
    reporters.set(setOf(ReporterType.CHECKSTYLE, ReporterType.JSON))
}


configure<GithookExtension> {
    githook {
        hooks {
            create("pre-push") {
                task = "build"
            }
        }
    }
}

val sourcesJar by tasks.creating(Jar::class) {
    classifier = "sources"
    println(sourceSets["main"].allSource)
    from(sourceSets["main"].allSource)
}

val shadowJar by tasks.getting(ShadowJar::class) {
    classifier = "uber"
    manifest {
        attributes(mapOf("Main-Class" to "io.hexlabs.kloudformation.runner.DeployKt"))
    }
}


artifacts {
    add("archives", shadowJar)
}

bintray {
    user = "hexlabs-builder"
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
            pom.withXml {
                val dependencies = (asNode()["dependencies"] as NodeList)
                configurations.compile.allDependencies.forEach {
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