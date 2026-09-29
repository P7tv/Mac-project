// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SweepSpace",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SweepSpaceCore",
            targets: ["SweepSpaceCore"]
        ),
        .executable(
            name: "SweepSpace",
            targets: ["SweepSpace"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SweepSpaceCore",
            dependencies: []
        ),
        .executableTarget(
            name: "SweepSpace",
            dependencies: ["SweepSpaceCore"]
        ),
        .testTarget(
            name: "SweepSpaceTests",
            dependencies: ["SweepSpaceCore"]
        )
    ]
)
