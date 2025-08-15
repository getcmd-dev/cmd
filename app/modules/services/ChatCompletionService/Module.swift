Target.module(
  name: "ChatCompletionService",
  dependencies: [
    .product(name: "Vapor", package: "vapor"),
    "AppFoundation",
    "ChatCompletionServiceInterface",
    "ConcurrencyFoundation",
    "DependencyFoundation",
    "FoundationInterfaces",
    "JSONFoundation",
    "LoggingServiceInterface",
    "SettingsServiceInterface",
    "ThreadSafe",
  ],
  testDependencies: [
    "AppFoundation",
  ])
