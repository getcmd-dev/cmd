Target.module(
  name: "CheckpointServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "ConcurrencyFoundation",
  ],
  testDependencies: [
    "AppFoundation",
    "CheckpointServiceInterface",
    "ConcurrencyFoundation",
    "SwiftTesting",
  ])
