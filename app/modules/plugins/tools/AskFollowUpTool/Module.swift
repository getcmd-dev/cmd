Target.module(
  name: "AskFollowUpTool",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "ConcurrencyFoundation",
    "DLS",
    "JSONFoundation",
    "LocalServerServiceInterface",
    "ToolFoundation",
  ],
  testsDependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "AskFollowUpTool",
    "SwiftTesting",
    "ToolFoundation",
  ])
