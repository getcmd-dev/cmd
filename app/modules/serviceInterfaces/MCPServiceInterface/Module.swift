Target.module(
  name: "MCPServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "ConcurrencyFoundation",
    "DependencyFoundation",
    "SettingsServiceInterface",
    "ThreadSafe",
    "ToolFoundation",
  ])
