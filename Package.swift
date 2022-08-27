// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "gwncli",
    platforms: [
            .macOS(.v12)
        ],
    dependencies: [
        .package(url: "https://github.com/teufelaudio/FoundationExtensions", branch: "linux-compat"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "gwncli",
            dependencies: [
                "FoundationExtensions",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
        .testTarget(
            name: "gwncliTests",
            dependencies: ["gwncli"],
            resources: [.copy("Resources/")]),
    ]
)
