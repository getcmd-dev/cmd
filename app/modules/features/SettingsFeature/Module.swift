Target.module(
  name: "SettingsFeature",
  dependencies: [
    "AppUpdateServiceInterface",
    "ChatFoundation",
    "ConcurrencyFoundation",
    "DLS",
    "FoundationInterfaces",
    "LLMFoundation",
    "SettingsServiceInterface",
    "ToolFoundation",
  ],
  testDependencies: [
    "FoundationInterfaces",
    "LLMFoundation",
    "SettingsServiceInterface",
    "SwiftTesting",
  ])
