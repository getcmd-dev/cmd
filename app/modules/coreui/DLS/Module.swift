Target.module(
  name: "DLS",
  dependencies: [
    "AppFoundation",
    "ConcurrencyFoundation",
    "LoggingServiceInterface",
  ],
  resources: [
    .process("Resources/cmd-logo.svg"),
  ],
  testsDependencies: [
    "DLS",
  ])
