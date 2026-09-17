// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DropMorph",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "DropMorph",
            targets: ["DropMorph"]
        ),
        .library(
            name: "DropMorphCore",
            targets: ["DropMorphCore"]
        )
    ],
    targets: [
        .target(
            name: "DropMorphCore",
            path: "Sources/DropMorphCore"
        ),
        .executableTarget(
            name: "DropMorph",
            dependencies: ["DropMorphCore"],
            path: "Sources/DropMorph"
        ),
        .testTarget(
            name: "DropMorphTests",
            dependencies: ["DropMorphCore"],
            path: "Tests/DropMorphTests"
        )
    ]
)
