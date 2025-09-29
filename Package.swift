// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TOME",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "TOME",
            targets: ["TOME"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "TOME",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Sources",
            resources: [
                .copy("TOME/Resources")
            ]
        )
    ]
)