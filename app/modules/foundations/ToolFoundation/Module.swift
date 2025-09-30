Target.module(
  name: "ToolFoundation",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "ChatFoundation",
    "ConcurrencyFoundation",
    "DependencyFoundation",
    "JSONFoundation",
    "LoggingServiceInterface",
    "ThreadSafe",
  ],
  testDependencies: [
    "AppFoundation",
    "ConcurrencyFoundation",
    "JSONFoundation",
    "SwiftTesting",
    "ThreadSafe",
  ])
