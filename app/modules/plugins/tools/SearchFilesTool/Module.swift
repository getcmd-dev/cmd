Target.module(
  name: "SearchFilesTool",
  dependencies: [
    "AppFoundation",
    "ConcurrencyFoundation",
    "DLS",
    "JSONFoundation",
    "LoggingServiceInterface",
    "ServerServiceInterface",
    "ToolFoundation",
  ],
  testDependencies: [
    "JSONFoundation",
    "ServerServiceInterface",
    "SwiftTesting",
    "ToolFoundation",
  ])
