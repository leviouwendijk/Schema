// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "SchemaTests",
    // platforms: [
    //     .macOS(.v13),
    // ],
    products: [
        .executable(
            name: "schematest",
            targets: ["SchemaTests"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Primitives.git",
            branch: "master"
        ),
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "SchemaTests",
            dependencies: [
                .product(name: "Schema", package: "Schema"),
                .product(
                    name: "Primitives",
                    package: "Primitives"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
