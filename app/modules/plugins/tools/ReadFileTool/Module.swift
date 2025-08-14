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
    "LocalServerServiceInterface",
    "LoggingServiceInterface",
    "ThreadSafe",
    "ToolFoundation",
  ],
  testDependencies: [
    "FoundationInterfaces",
    "JSONFoundation",
    "SwiftTesting",
    "ToolFoundation",
  ])
