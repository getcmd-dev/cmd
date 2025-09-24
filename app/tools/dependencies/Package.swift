// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "package-dependencies",
  platforms: [
    .macOS(.v13),
  ],
  products: [
    .library(name: "SyncPackageDependencies", targets: [
      "SyncPackageDependencies",
    ]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.1"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
  ],
  targets: [
    .executableTarget(
      name: "SyncPackageDependenciesCommand",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "SyncPackageDependencies",
      ],
      path: "Sources/Executable"),
    .target(
      name: "SyncPackageDependencies",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
      ],
      path: "Sources/Library"),
  ])
