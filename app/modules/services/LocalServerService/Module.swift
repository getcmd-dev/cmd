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
    .copy("Resources"),
  ],
  testDependencies: [
    "AppFoundation",
    "JSONFoundation",
    "LocalServerServiceInterface",
    "SwiftTesting",
  ])
