Target.module(
  name: "XcodeObserverService",
  dependencies: [
    .product(name: "XcodeProj", package: "XcodeProj"),
    "AccessibilityFoundation",
    "AppFoundation",
    "ConcurrencyFoundation",
    "DependencyFoundation",
    "FoundationInterfaces",
    "LoggingServiceInterface",
    "PermissionsServiceInterface",
    "SettingsServiceInterface",
    "ShellServiceInterface",
    "ThreadSafe",
    "XcodeObserverServiceInterface",
  ],
  testDependencies: [
    "ConcurrencyFoundation",
    "FoundationInterfaces",
    "LoggingServiceInterface",
    "PermissionsServiceInterface",
    "SettingsServiceInterface",
    "ShellServiceInterface",
    "SwiftTesting",
    "XcodeObserverServiceInterface",
  ],
  testResources: [
    .copy("resources/"),
  ])
