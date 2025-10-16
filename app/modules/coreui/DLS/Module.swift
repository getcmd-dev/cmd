Target.module(
  name: "DLS",
  dependencies: [
    "AppFoundation",
    "ConcurrencyFoundation",
    "LoggingServiceInterface",
  ],
  resources: [
    .process("Resources/cmd-logo.svg"),
    .process("Resources/mcp.svg"),
  ],
  testsDependencies: [
    "DLS",
  ])
