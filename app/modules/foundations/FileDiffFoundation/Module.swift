Target.module(
  name: "FileDiffFoundation",
  dependencies: [
    .product(name: "HighlightSwift", package: "highlightswift"),
    "AppFoundation",
    "FileDiffTypesFoundation",
    "LoggingServiceInterface",
  ],
  testsDependencies: [
    .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
    "FileDiffFoundation",
    "FileDiffTypesFoundation",
  ],
  testsExclude: ["__Snapshots__"])
