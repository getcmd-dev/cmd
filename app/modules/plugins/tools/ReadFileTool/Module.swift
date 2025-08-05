Target.module(
  name: "ReadFileTool",
  dependencies: [
    "AppFoundation",
    "ChatServiceInterface",
    "CodePreview",
    "ConcurrencyFoundation",
    "DLS",
    "FoundationInterfaces",
    "HighlighterServiceInterface",
    "JSONFoundation",
    "ServerServiceInterface",
    "ToolFoundation",
  ],
  testDependencies: [
    "FoundationInterfaces",
    "JSONFoundation",
    "SwiftTesting",
    "ToolFoundation",
  ])
