// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FileCleanerAI",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "FileCleanerAI",
            targets: ["FileCleanerAI"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "FileCleanerAI",
            path: "FileCleanerAI",
            linkerSettings: [
                .linkedFramework("FoundationModels", .when(platforms: [.macOS]))
            ]
        )
    ]
)

