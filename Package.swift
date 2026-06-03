// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BubbleKit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "BubbleKit",
            targets: ["BubbleKit"]
        ),
    ],
    targets: [
        .target(
            name: "BubbleKit",
            path: "BubbleKit/BubbleKit"
        )
    ]
)
