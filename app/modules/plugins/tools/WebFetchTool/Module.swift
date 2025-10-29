Target.module(
  name: "WebFetchTool",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    .product(name: "SwiftSoup", package: "SwiftSoup"),
    "AppFoundation",
    "ConcurrencyFoundation",
    "DLS",
    "JSONFoundation",
    "LLMServiceInterface",
    "LocalServerServiceInterface",
    "LoggingServiceInterface",
    "ToolFoundation",
    "ToolTypesFoundation",
  ])
