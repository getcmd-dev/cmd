Target.module(
  name: "LocalServerService",
  dependencies: [
    "AppEventServiceInterface",
    "AppFoundation",
    "ConcurrencyFoundation",
    "DependencyFoundation",
    "ExtensionEventsInterface",
    "FoundationInterfaces",
    "LocalServerServiceInterface",
    "LoggingServiceInterface",
    "ThreadSafe",
  ],
  resources: [
    .process("Resources/build.sha256"),
    .process("Resources/launch-server.sh"),
    .process("Resources/main.bundle.cjs.gz"),
    .process("Resources/main.bundle.cjs.map"),
  ],
  testDependencies: [
    "AppFoundation",
    "JSONFoundation",
    "LocalServerServiceInterface",
    "SwiftTesting",
  ])
