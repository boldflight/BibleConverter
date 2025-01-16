// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BibleConverter",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
        .package(url: "https://github.com/drmohundro/SWXMLHash.git", from: "8.0.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0")
    ],
    targets: [
        .executableTarget(
            name: "BibleConverter",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "ZIPFoundation",
                "SWXMLHash",
                "SwiftSoup"
            ]
        ),
        .testTarget(
            name: "BibleConverterTests",
            dependencies: ["BibleConverter"]
        )
    ]
)
