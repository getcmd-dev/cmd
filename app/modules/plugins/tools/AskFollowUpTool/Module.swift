Target.module(
  name: "AskFollowUpTool",
  dependencies: [
    "AppFoundation",
    "ConcurrencyFoundation",
    "DLS",
    "JSONFoundation",
    "LocalServerServiceInterface",
    "ToolFoundation",
  ],
  testDependencies: [
    "LocalServerServiceInterface",
    "LSTool",
    "SwiftTesting",
    "ToolFoundation",
  ])
