// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SpockSwift",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .macCatalyst(.v16)
    ],
    products: [
        .library(
            name: "SpockSwift",
            targets: ["SpockSwift"]
        ),
        .library(
            name: "SpockGenCore",
            targets: ["SpockGenCore"]
        ),
        .executable(
            name: "spock-gen",
            targets: ["SpockGenCLI"]
        ),
        .plugin(
            name: "SpockPlugin",
            targets: ["SpockPlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0"..<"602.0.0")
    ],
    targets: [
        // 1. Compiler Plugin nativo (Swift Macros: @Stub marker)
        .macro(
            name: "SpockSwiftMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ],
            path: "Sources/SpockSwiftMacros"
        ),

        // 2. Biblioteca principal de testing: @Stub y SpockMock (@Stubbed, Spy, Stub)
        .target(
            name: "SpockSwift",
            dependencies: ["SpockSwiftMacros"],
            path: "Sources/SpockSwift"
        ),

        // 3. Motor de generación: parsing AST, autoTree, deduplicación y caché
        .target(
            name: "SpockGenCore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            path: "Sources/SpockGenCore"
        ),

        // 4. Herramienta CLI ejecutable
        .executableTarget(
            name: "SpockGenCLI",
            dependencies: ["SpockGenCore"],
            path: "Sources/SpockGenCLI"
        ),

        // 5. SPM BuildToolPlugin para automatización en prebuild
        .plugin(
            name: "SpockPlugin",
            capability: .buildTool(),
            dependencies: ["SpockGenCLI"],
            path: "Plugins/SpockPlugin"
        ),

        // 6. Pruebas del cliente SpockSwift
        .testTarget(
            name: "SpockSwiftTests",
            dependencies: ["SpockSwift"],
            path: "Tests/SpockSwiftTests"
        ),

        // 7. Pruebas del motor SpockGenCore
        .testTarget(
            name: "SpockGenTests",
            dependencies: ["SpockGenCore"],
            path: "Tests/SpockGenTests"
        ),

        // 8. Módulo de Dominio del Example
        .target(
            name: "Example",
            path: "Example/Example/Domain"
        ),

        // 9. Pruebas del Example usando SpockSwift y SpockPlugin
        .testTarget(
            name: "ExampleTests",
            dependencies: [
                "Example",
                "SpockSwift"
            ],
            path: "Example/ExampleTests"
        )
    ]
)
