// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "WaterBridgeKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "WaterBridgeKit",
            targets: ["WaterBridgeKit"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.25.5"
        ),
        .package(
            url: "https://github.com/microsoft/plcrashreporter.git",
            from: "1.12.2"
        )
    ],
    targets: [
        .target(
            name: "WaterBridgeCore",
            path: "Sources/Core"
        ),
        .target(
            name: "WaterBridgeKit",
            dependencies: [
                "WaterBridgeCore",
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"
                ),
                .product(
                    name: "CrashReporter",
                    package: "plcrashreporter"
                )
            ],
            path: "Sources/Features"
        ),
        .testTarget(
            name: "WaterBridgeCoreTests",
            dependencies: ["WaterBridgeCore"],
            path: "Tests/WaterBridgeCoreTests"
        ),
        .testTarget(
            name: "WaterBridgeKitTests",
            dependencies: ["WaterBridgeKit", "WaterBridgeCore"],
            path: "Tests/WaterBridgeKitTests"
        )
    ]
)
