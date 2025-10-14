Target.module(
  name: "ChatServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "ChatFeatureInterface",
    "ThreadSafe",
    "ToolFoundation",
  ],
  testsDependencies: [
    "AppFoundation",
    "ChatFeatureInterface",
    "ChatServiceInterface",
    "ConcurrencyFoundation",
    "SwiftTesting",
  ])
