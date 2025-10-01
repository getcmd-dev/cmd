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
    "LLMServiceInterface",
    "LoggingServiceInterface",
    "SettingsServiceInterface",
    "ThreadSafe",
  ],
  testDependencies: [
    "AppFoundation",
  ])
