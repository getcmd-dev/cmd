Target.module(
  name: "CheckpointServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "ConcurrencyFoundation",
  ],
  testsDependencies: [
    "AppFoundation",
    "CheckpointServiceInterface",
    "ConcurrencyFoundation",
    "SwiftTesting",
  ])
