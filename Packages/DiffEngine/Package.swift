// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DiffEngine",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "DiffEngine",
            targets: ["DiffEngine"]
        ),
    ],
    targets: [
        .target(
            name: "DiffEngine",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "DiffEngineTests",
            dependencies: ["DiffEngine"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
