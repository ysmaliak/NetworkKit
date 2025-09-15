// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NetworkKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "NetworkKit",
            targets: ["NetworkKit"]
        )
    ],
    targets: [
        .target(
            name: "NetworkKit",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        )
    ]
)
