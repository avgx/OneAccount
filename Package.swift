// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OneAccount",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .tvOS(.v18),
        .macOS(.v13),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "OneAccount",
            targets: ["OneAccount"]
        ),
        .library(
            name: "OneAccountUI",
            targets: ["OneAccountUI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/auth0/JWTDecode.swift", from: "4.0.0"),
        .package(url: "https://github.com/avgx/SSLPinning", from: "1.0.2"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.10.1"),
        .package(url: "https://github.com/avgx/RequestResponse.git", from: "2.0.0"),
        .package(url: "https://github.com/avgx/EncodeDecode.git", from: "1.0.1"),
        .package(url: "https://github.com/avgx/URLKit.git", from: "1.0.0"),
        .package(url: "https://github.com/avgx/DebugThings.git", branch: "main"),
        .package(url: "https://github.com/avgx/Get.git", branch: "dev"),
        .package(url: "https://github.com/avgx/ButtonKit", branch: "main"),
        .package(url: "https://github.com/avgx/SwiftUI-Shimmer", branch: "main"),
        .package(url: "https://github.com/avgx/OneDiscovery", branch: "main"),
    ],
    targets: [
        .target(
            name: "OneAccount",
            dependencies: [
                "OneDiscovery",
                .product(name: "JWTDecode", package: "JWTDecode.swift"),
                .product(name: "RequestResponse", package: "RequestResponse"),
                .product(name: "EncodeDecode", package: "EncodeDecode"),
                .product(name: "SSLPinning", package: "SSLPinning"),
                .product(name: "DebugThings", package: "DebugThings"),
                .product(name: "URLKit", package: "URLKit"),
                .product(name: "HTTP", package: "Get"),
            ]
        ),
        .target(
            name: "OneAccountUI",
            dependencies: [
                "OneAccount",
                "OneDiscovery",
                .product(name: "JWTDecode", package: "JWTDecode.swift"),
                .product(name: "RequestResponse", package: "RequestResponse"),
                .product(name: "EncodeDecode", package: "EncodeDecode"),
                .product(name: "SSLPinning", package: "SSLPinning"),
                .product(name: "DebugThings", package: "DebugThings"),
                .product(name: "URLKit", package: "URLKit"),
                .product(name: "HTTP", package: "Get"),
                .product(name: "ButtonKit", package: "ButtonKit"),
                .product(name: "Shimmer", package: "SwiftUI-Shimmer"),
            ]
        ),
        .testTarget(
            name: "OneAccountTests",
            dependencies: [
                "OneAccount", "OneAccountUI", "OneDiscovery",
                .product(name: "JWTDecode", package: "JWTDecode.swift"),
                .product(name: "RequestResponse", package: "RequestResponse"),
                .product(name: "EncodeDecode", package: "EncodeDecode"),
                .product(name: "SSLPinning", package: "SSLPinning"),
                .product(name: "DebugThings", package: "DebugThings"),
                .product(name: "URLKit", package: "URLKit"),
                .product(name: "HTTP", package: "Get"),
                .product(name: "WS", package: "Get"),
            ]
        ),
    ]
)
