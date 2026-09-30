// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GhostTranslate",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "GhostTranslateCore", targets: ["GhostTranslateCore"]),
        .executable(name: "GhostTranslate", targets: ["GhostTranslateAppTarget"])
    ],
    targets: [
        .target(
            name: "GhostTranslateCore",
            dependencies: [],
            path: "Sources/GhostTranslateCore"
        ),
        .executableTarget(
            name: "GhostTranslateAppTarget",
            dependencies: ["GhostTranslateCore"],
            path: "Sources/GhostTranslateAppTarget"
        ),
        .testTarget(
            name: "GhostTranslateTests",
            dependencies: ["GhostTranslateCore"],
            path: "Tests/GhostTranslateTests"
        )
    ]
)
