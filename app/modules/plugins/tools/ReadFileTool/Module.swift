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
    "LoggingServiceInterface",
    "ServerServiceInterface",
    "ToolFoundation",
  ],
  testDependencies: [
    "FoundationInterfaces",
    "JSONFoundation",
    "SwiftTesting",
    "ToolFoundation",
  ])
