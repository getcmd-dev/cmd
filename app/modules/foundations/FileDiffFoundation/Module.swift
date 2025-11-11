Target.module(
  name: "FileDiffFoundation",
  dependencies: [
    .product(name: "Algorithms", package: "swift-algorithms"),
    .product(name: "HighlightSwift", package: "highlightswift"),
    "AppFoundation",
    "FileDiffTypesFoundation",
    "LoggingServiceInterface",
  ],
  testsDependencies: [
    .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
    "AppFoundation",
    "FileDiffFoundation",
    "FileDiffTypesFoundation",
  ],
  testsExclude: ["__Snapshots__"])
