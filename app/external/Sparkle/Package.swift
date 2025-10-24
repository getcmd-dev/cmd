// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Sparkle",
    platforms: [.macOS(.v10_13)],
    products: [
        .library(
            name: "Sparkle",
            targets: ["Sparkle"])
    ],
    targets: [
        .binaryTarget(
            name: "Sparkle",
            path: "Sparkle.xcframework"
        )
    ]
)
