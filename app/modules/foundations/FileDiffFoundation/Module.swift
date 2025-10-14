Target.module(
  name: "FileDiffFoundation",
  dependencies: [
    .product(name: "HighlightSwift", package: "highlightswift"),
    "AppFoundation",
    "FileDiffTypesFoundation",
    "LoggingServiceInterface",
  ],
  testDependencies: [
    .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
    "FileDiffFoundation",
    "FileDiffTypesFoundation",
  ],
  testExclude: ["__Snapshots__"])
