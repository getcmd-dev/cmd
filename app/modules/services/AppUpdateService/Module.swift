Target.module(
  name: "AppUpdateService",
  dependencies: [
    .product(name: "Sparkle", package: "Sparkle"),
    "AppFoundation",
    "AppUpdateServiceInterface",
    "DependencyFoundation",
    "FoundationInterfaces",
    "LoggingServiceInterface",
    "SettingsServiceInterface",
    "ThreadSafe",
  ],
  testsDependencies: [])
