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
    "AppFoundation",
    "JSONFoundation",
    "ServerServiceInterface",
    "SwiftTesting",
    "ToolFoundation",
  ])
