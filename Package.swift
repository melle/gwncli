// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "gwncli",
    platforms: [
            .macOS(.v13),
            .linux
        ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "gwncli",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]),
        .testTarget(
            name: "gwncliTests",
            dependencies: ["gwncli"],
            resources: [.copy("Resources/")]),
    ]
)
