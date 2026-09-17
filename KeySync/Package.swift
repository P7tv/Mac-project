// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeySync",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "KeySync",
            targets: ["KeySync"]
        ),
        .library(
            name: "KeySyncCore",
            targets: ["KeySyncCore"]
        )
    ],
    targets: [
        .target(
            name: "KeySyncCore",
            path: "Sources/KeySyncCore"
        ),
        .executableTarget(
            name: "KeySync",
            dependencies: ["KeySyncCore"],
            path: "Sources/KeySync"
        ),
        .testTarget(
            name: "KeySyncTests",
            dependencies: ["KeySyncCore"],
            path: "Tests/KeySyncTests"
        )
    ]
)
