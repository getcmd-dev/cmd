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
  testsDependencies: [
    "AppFoundation",
    "ConcurrencyFoundation",
    "JSONFoundation",
    "SwiftTesting",
    "ThreadSafe",
    "ToolFoundation",
  ])
