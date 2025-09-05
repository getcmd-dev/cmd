Target.module(
  name: "DLS",
  dependencies: [
    "AppFoundation",
    "ConcurrencyFoundation",
    "FoundationInterfaces",
    "LocalServerServiceInterface",
    "LoggingServiceInterface",
    "ShellServiceInterface",
  ],
  resources: [
    .process("Resources/fileIcons"),
    .process("Resources/cmd-logo.svg"),
  ],
  testDependencies: [])
