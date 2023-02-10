// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "moveme",
    dependencies: [
        .package(url: "https://github.com/tmandry/AXSwift", from: "0.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "moveme",
            dependencies: ["AXSwift"]
        ),
    ]
)
