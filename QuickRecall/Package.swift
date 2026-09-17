// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuickRecall",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "QuickRecall",
            targets: ["QuickRecall"]
        ),
        .library(
            name: "QuickRecallCore",
            targets: ["QuickRecallCore"]
        )
    ],
    targets: [
        .target(
            name: "QuickRecallCore",
            path: "Sources/QuickRecallCore"
        ),
        .executableTarget(
            name: "QuickRecall",
            dependencies: ["QuickRecallCore"],
            path: "Sources/QuickRecall"
        ),
        .testTarget(
            name: "QuickRecallTests",
            dependencies: ["QuickRecallCore"],
            path: "Tests/QuickRecallTests"
        )
    ]
)
