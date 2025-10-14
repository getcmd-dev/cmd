Target.module(
  name: "DLS",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
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
  testDependencies: [
    "DLS",
  ])
