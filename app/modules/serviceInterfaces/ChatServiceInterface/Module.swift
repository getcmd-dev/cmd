Target.module(
  name: "ChatServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "ChatFeatureInterface",
    "ThreadSafe",
    "ToolFoundation",
  ],
  testDependencies: [
    "AppFoundation",
    "ChatFeatureInterface",
    "ConcurrencyFoundation",
    "SwiftTesting",
  ])
