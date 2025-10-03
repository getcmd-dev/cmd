Target.module(
  name: "SettingsService",
  dependencies: [
    "AppFoundation",
    "ConcurrencyFoundation",
    "DependencyFoundation",
    "FoundationInterfaces",
    "JSONFoundation",
    "LLMFoundation",
    "LoggingServiceInterface",
    "SettingsServiceInterface",
    "SharedValuesFoundation",
    "ThreadSafe",
  ],
  testDependencies: [
    "ConcurrencyFoundation",
    "FoundationInterfaces",
    "LLMFoundation",
    "SettingsServiceInterface",
    "SharedValuesFoundation",
    "SwiftTesting",
  ])
