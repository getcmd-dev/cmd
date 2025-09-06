Target.module(
  name: "SettingsFeature",
  dependencies: [
    "AppFoundation",
    "AppUpdateServiceInterface",
    "ChatFoundation",
    "ConcurrencyFoundation",
    "DLS",
    "FoundationInterfaces",
    "LLMFoundation",
    "LocalServerServiceInterface",
    "LoggingServiceInterface",
    "SettingsServiceInterface",
    "ShellServiceInterface",
    "ToolFoundation",
  ],
  testDependencies: [
    "FoundationInterfaces",
    "LLMFoundation",
    "SettingsServiceInterface",
    "SwiftTesting",
  ])
