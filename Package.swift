// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-secret-service",
    platforms: [.macOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SecretService",
            targets: ["SecretService"]),
    ],
    dependencies: [
        .package(url: "https://github.com/wendylabsinc/dbus.git", .upToNextMinor(from: "0.4.0")),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", .upToNextMajor(from: "1.10.0")),
        .package(url: "https://github.com/attaswift/BigInt.git", .upToNextMajor(from: "5.7.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SecretService",
            dependencies: [
                .product(name: "DBUS", package: "dbus"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
                .product(name: "BigInt", package: "BigInt")
            ]
        ),
        .testTarget(
            name: "swift-secret-serviceTests",
            dependencies: ["SecretService"]
        )
    ]
)
