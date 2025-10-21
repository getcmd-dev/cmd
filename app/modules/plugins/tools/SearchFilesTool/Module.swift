Target.module(
  name: "SearchFilesTool",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "ConcurrencyFoundation",
    "DLS",
    "FileIcon",
    "JSONFoundation",
    "LocalServerServiceInterface",
    "LoggingServiceInterface",
    "ToolFoundation",
    "ToolTypesFoundation",
  ],
  testsDependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "JSONFoundation",
    "LocalServerServiceInterface",
    "SearchFilesTool",
    "SwiftTesting",
    "ToolFoundation",
    "ToolTypesFoundation",
  ])
