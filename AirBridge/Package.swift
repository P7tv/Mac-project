// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AirBridge",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "AirBridge",
            targets: ["AirBridge"]
        ),
        .library(
            name: "AirBridgeCore",
            targets: ["AirBridgeCore"]
        )
    ],
    targets: [
        .target(
            name: "AirBridgeCore",
            path: "Sources/AirBridgeCore"
        ),
        .executableTarget(
            name: "AirBridge",
            dependencies: ["AirBridgeCore"],
            path: "Sources/AirBridge"
        ),
        .testTarget(
            name: "AirBridgeTests",
            dependencies: ["AirBridgeCore"],
            path: "Tests/AirBridgeTests"
        )
    ]
)
