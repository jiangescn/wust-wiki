allprojects {
    repositories { google(); mavenCentral() }
}
rootProject.layout.buildDirectory.set(file("../build"))
subprojects {
    layout.buildDirectory.set(rootProject.layout.buildDirectory.dir(name))
}
