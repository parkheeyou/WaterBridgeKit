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
                )
            ],
            path: "Sources/Features"
        )
    ]
)
