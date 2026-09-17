// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AudioTunnel",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "AudioTunnel",
            targets: ["AudioTunnel"]
        ),
        .library(
            name: "AudioTunnelCore",
            targets: ["AudioTunnelCore"]
        )
    ],
    targets: [
        .target(
            name: "AudioTunnelCore",
            path: "Sources/AudioTunnelCore"
        ),
        .executableTarget(
            name: "AudioTunnel",
            dependencies: ["AudioTunnelCore"],
            path: "Sources/AudioTunnel"
        ),
        .testTarget(
            name: "AudioTunnelTests",
            dependencies: ["AudioTunnelCore"],
            path: "Tests/AudioTunnelTests"
        )
    ]
)
