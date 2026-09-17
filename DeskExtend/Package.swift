// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeskExtend",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "DeskExtend",
            targets: ["DeskExtend"]
        ),
        .library(
            name: "DeskExtendCore",
            targets: ["DeskExtendCore"]
        )
    ],
    targets: [
        .target(
            name: "DeskExtendBridge",
            path: "Sources/DeskExtendBridge",
            publicHeadersPath: "include"
        ),
        .target(
            name: "DeskExtendCore",
            dependencies: ["DeskExtendBridge"],
            path: "Sources/DeskExtendCore"
        ),
        .executableTarget(
            name: "DeskExtend",
            dependencies: ["DeskExtendCore"],
            path: "Sources/DeskExtend"
        ),
        .testTarget(
            name: "DeskExtendTests",
            dependencies: ["DeskExtendCore"],
            path: "Tests/DeskExtendTests"
        )
    ]
)
