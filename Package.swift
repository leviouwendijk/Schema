// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Schema",
    // platforms: [
    //     .macOS(.v13),
    // ],
    products: [
        .library(
            name: "Schema",
            targets: [
                "Schema",
            ]
        ),
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
    ],
    targets: [
        .target(
            name: "Schema",
            dependencies: [
                .product(
                    name: "Primitives",
                    package: "Primitives"
                ),
            ]
        ),
        .executableTarget(
            name: "SchemaTests",
            dependencies: [
                "Schema",
                .product(
                    name: "Primitives",
                    package: "Primitives"
                ),
            ],
            path: "Testing/SchemaTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
