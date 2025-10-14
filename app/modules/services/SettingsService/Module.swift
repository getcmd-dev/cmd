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
  testsDependencies: [
    "ConcurrencyFoundation",
    "FoundationInterfaces",
    "LLMFoundation",
    "SettingsService",
    "SettingsServiceInterface",
    "SharedValuesFoundation",
    "SwiftTesting",
  ])
