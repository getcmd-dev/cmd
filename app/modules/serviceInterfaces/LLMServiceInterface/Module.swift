Target.module(
  name: "LLMServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "ChatFoundation",
    "ConcurrencyFoundation",
    "JSONFoundation",
    "LLMFoundation",
    "LocalServerServiceInterface",
    "ThreadSafe",
    "ToolFoundation",
  ],
  testDependencies: [])
