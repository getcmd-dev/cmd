Target.module(
  name: "AppExtension",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AccessibilityFoundation",
    "ConcurrencyFoundation",
    "DependencyFoundation",
    "ExtensionEventsInterface",
    "FileDiffFoundation",
    "FileDiffTypesFoundation",
    "FoundationInterfaces",
    "LoggingService",
    "LoggingServiceInterface",
    "SettingsService",
    "SettingsServiceInterface",
    "SharedUtilsFoundation",
    "SharedValuesFoundation",
    "ThreadSafe",
  ])
