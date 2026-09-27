// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RarPeek",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "RarPeek", targets: ["RarPeek"]),
        .library(name: "RarPeekCore", targets: ["RarPeekCore"])
    ],
    targets: [
        .target(
            name: "RarPeekCore",
            dependencies: [],
            path: "Sources/RarPeekCore"
        ),
        .executableTarget(
            name: "RarPeek",
            dependencies: ["RarPeekCore"],
            path: "Sources/RarPeek"
        ),
        .testTarget(
            name: "RarPeekTests",
            dependencies: ["RarPeekCore"],
            path: "Tests/RarPeekTests"
        )
    ]
)
