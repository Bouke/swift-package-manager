import PackageDescription

let package = Package(
    name: "App",
    dependencies: [
        .Package(url: "../Foo", majorVersion: 1)
    ],
    testDependencies: [
        .Package(url: "../TestingLib", majorVersion: 1)
    ]
)
