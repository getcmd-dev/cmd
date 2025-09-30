// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "TestSPM",
  products: [
    .library(name: "TestSPM", targets: ["TestSPM"]),
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "TestSPM"),
    .testTarget(
      name: "TestSPMTests",
      dependencies: ["TestSPM"]),
  ])
