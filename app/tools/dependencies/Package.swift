// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "swift-module",
  platforms: [
    .macOS(.v13),
  ],
  products: [
    .library(
      name: "SwiftModule",
      targets: [
        "SwiftModule",
      ]),
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.6.2"),
    .package(url: "https://github.com/swiftlang/swift-format", from: "602.0.0"),
  ],
  targets: [
    .executableTarget(
      name: "SwiftModuleCommand",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "SwiftModule",
      ],
      path: "Sources/Executable"),
    .target(
      name: "SwiftModule",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftFormat", package: "swift-format"),
      ],
      path: "Sources/Library"),
    .testTarget(
      name: "SwiftModuleTests",
      dependencies: [
        "SwiftModule",
      ],
      path: "Tests",
      resources: [.copy("resources")]),
  ])
