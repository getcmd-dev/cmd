Target.module(
  name: "ServerService",
  dependencies: [
    "AppEventServiceInterface",
    "AppFoundation",
    "ConcurrencyFoundation",
    "DependencyFoundation",
    "ExtensionEventsInterface",
    "FoundationInterfaces",
    "LoggingServiceInterface",
    "ServerServiceInterface",
    "ThreadSafe",
  ],
  resources: [
    .process("Resources/build.sha256"),
    .process("Resources/launch-server.sh"),
    .process("Resources/main.bundle.cjs"),
    .process("Resources/main.bundle.cjs.map"),
  ],
  testDependencies: [
    "AppFoundation",
    "JSONFoundation",
    "ServerServiceInterface",
    "SwiftTesting",
  ])
