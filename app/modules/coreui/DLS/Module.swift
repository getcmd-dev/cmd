Target.module(
  name: "DLS",
  dependencies: [
    "AppFoundation",
    "ConcurrencyFoundation",
    "LocalServerServiceInterface",
    "LoggingServiceInterface",
  ],
  resources: [
    .process("Resources/fileIcons"),
    .process("Resources/cmd-logo.svg"),
  ],
  testDependencies: [])
