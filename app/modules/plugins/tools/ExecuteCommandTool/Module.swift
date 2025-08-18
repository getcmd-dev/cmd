Target.module(
  name: "ExecuteCommandTool",
  dependencies: [
    "AppFoundation",
    "CodePreview",
    "ConcurrencyFoundation",
    "DLS",
    "JSONFoundation",
    "LocalServerServiceInterface",
    "ShellServiceInterface",
    "ThreadSafe",
    "ToolFoundation",
  ],
  testDependencies: [
    "AppFoundation",
    "ConcurrencyFoundation",
    "LocalServerServiceInterface",
    "ShellServiceInterface",
    "SwiftTesting",
    "ToolFoundation",
  ])
