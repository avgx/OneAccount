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
        .package(url: "https://github.com/avgx/OneDiscovery", from: "1.0.0"),
        .package(url: "https://github.com/auth0/JWTDecode.swift", from: "4.0.0"),
        .package(url: "https://github.com/avgx/SSLPinning.git", from: "2.0.0"),
        .package(url: "https://github.com/avgx/TLSDiagnostics.git", from: "1.0.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.10.1"),
        .package(url: "https://github.com/avgx/RequestResponse.git", from: "2.0.0"),
        .package(url: "https://github.com/avgx/EncodeDecode.git", from: "1.0.2"),
        .package(url: "https://github.com/avgx/URLKit.git", from: "1.0.0"),
        .package(url: "https://github.com/avgx/DebugThings.git", from: "2.0.0"),
        .package(url: "https://github.com/avgx/Resource.git", from: "1.0.0"),
        .package(url: "https://github.com/avgx/Get.git", from: "6.1.0"),
        .package(url: "https://github.com/Dean151/ButtonKit.git", from: "0.7.1"),
        .package(url: "https://github.com/markiv/SwiftUI-Shimmer", from: "1.5.1"),
    ],
    targets: [
        .target(
            name: "OneAccount",
            dependencies: [
                .product(name: "OneDiscovery", package: "OneDiscovery"),
                .product(name: "JWTDecode", package: "JWTDecode.swift"),
                .product(name: "RequestResponse", package: "RequestResponse"),
                .product(name: "EncodeDecode", package: "EncodeDecode"),
                .product(name: "SSLPinning", package: "SSLPinning"),
                .product(name: "TLSDiagnostics", package: "TLSDiagnostics"),
                .product(name: "DebugThings", package: "DebugThings"),
                .product(name: "Resource", package: "Resource"),
                .product(name: "URLKit", package: "URLKit"),
                .product(name: "HTTP", package: "Get"),
            ]
        ),
        .target(
            name: "OneAccountUI",
            dependencies: [
                "OneAccount",
                .product(name: "OneDiscovery", package: "OneDiscovery"),
                .product(name: "JWTDecode", package: "JWTDecode.swift"),
                .product(name: "RequestResponse", package: "RequestResponse"),
                .product(name: "EncodeDecode", package: "EncodeDecode"),
                .product(name: "SSLPinning", package: "SSLPinning"),
                .product(name: "TLSDiagnostics", package: "TLSDiagnostics"),
                .product(name: "DebugThings", package: "DebugThings"),
                .product(name: "Resource", package: "Resource"),
                .product(name: "URLKit", package: "URLKit"),
                .product(name: "HTTP", package: "Get"),
                .product(name: "ButtonKit", package: "ButtonKit"),
                .product(name: "Shimmer", package: "SwiftUI-Shimmer"),
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "OneAccountTests",
            dependencies: [
                "OneAccount",
                "OneAccountUI",
                .product(name: "OneDiscovery", package: "OneDiscovery"),
                .product(name: "JWTDecode", package: "JWTDecode.swift"),
                .product(name: "RequestResponse", package: "RequestResponse"),
                .product(name: "EncodeDecode", package: "EncodeDecode"),
                .product(name: "SSLPinning", package: "SSLPinning"),
                .product(name: "TLSDiagnostics", package: "TLSDiagnostics"),
                .product(name: "DebugThings", package: "DebugThings"),
                .product(name: "URLKit", package: "URLKit"),
                .product(name: "HTTP", package: "Get"),
                .product(name: "WS", package: "Get"),
            ]
        ),
    ]
)
