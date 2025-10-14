Target.module(
  name: "SearchFilesTool",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "ConcurrencyFoundation",
    "DLS",
    "JSONFoundation",
    "LocalServerServiceInterface",
    "LoggingServiceInterface",
    "ToolFoundation",
  ],
  testsDependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "JSONFoundation",
    "LocalServerServiceInterface",
    "SearchFilesTool",
    "SwiftTesting",
    "ToolFoundation",
  ])
