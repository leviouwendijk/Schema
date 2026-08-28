// swift-tools-version: 6.3

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Schema",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Schema",
            targets: ["Schema"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Primitives.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            from: "603.0.0"
        ),
    ],
    targets: [
        .macro(
            name: "SchemaMacros",
            dependencies: [
                .product(
                    name: "SwiftSyntax",
                    package: "swift-syntax"
                ),
                .product(
                    name: "SwiftSyntaxBuilder",
                    package: "swift-syntax"
                ),
                .product(
                    name: "SwiftSyntaxMacros",
                    package: "swift-syntax"
                ),
                .product(
                    name: "SwiftCompilerPlugin",
                    package: "swift-syntax"
                ),
            ]
        ),
        .target(
            name: "Schema",
            dependencies: [
                .product(
                    name: "Primitives",
                    package: "Primitives"
                ),
                "SchemaMacros",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
