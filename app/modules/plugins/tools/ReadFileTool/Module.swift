Target.module(
  name: "ReadFileTool",
  dependencies: [
    "AppFoundation",
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
