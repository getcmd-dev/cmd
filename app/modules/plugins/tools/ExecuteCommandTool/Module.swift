Target.module(
  name: "ExecuteCommandTool",
  dependencies: [
    "AppFoundation",
    "CodePreview",
    "ConcurrencyFoundation",
    "DLS",
    "JSONFoundation",
    "ServerServiceInterface",
    "ShellServiceInterface",
    "ThreadSafe",
    "ToolFoundation",
  ],
  testDependencies: [
    "ServerServiceInterface",
    "ShellServiceInterface",
    "SwiftTesting",
    "ToolFoundation",
  ])
