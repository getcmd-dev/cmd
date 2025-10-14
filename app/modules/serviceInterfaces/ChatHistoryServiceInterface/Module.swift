Target.module(
  name: "ChatHistoryServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "CheckpointServiceInterface",
    "LLMServiceInterface",
    "LocalServerServiceInterface",
    "LoggingServiceInterface",
    "ThreadSafe",
    "ToolFoundation",
  ],
  testsDependencies: [
    "AppFoundation",
    "ChatHistoryServiceInterface",
    "ConcurrencyFoundation",
    "SwiftTesting",
  ])
