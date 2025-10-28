Target.module(
  name: "LLMServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "ChatFoundation",
    "ConcurrencyFoundation",
    "JSONFoundation",
    "LLMFoundation",
    "LocalServerServiceInterface",
    "SettingsServiceInterface",
    "ThreadSafe",
    "ToolFoundation",
  ],
  testsDependencies: [])
