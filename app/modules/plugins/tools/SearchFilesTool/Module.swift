Target.module(
  name: "SearchFilesTool",
  dependencies: [
    "AppFoundation",
    "ConcurrencyFoundation",
    "DLS",
    "JSONFoundation",
    "LocalServerServiceInterface",
    "LoggingServiceInterface",
    "ToolFoundation",
  ],
  testDependencies: [
    "AppFoundation",
    "JSONFoundation",
    "LocalServerServiceInterface",
    "SwiftTesting",
    "ToolFoundation",
  ])
