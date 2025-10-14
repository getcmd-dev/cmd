Target.module(
  name: "LoggingService",
  dependencies: [
    .product(name: "Bugsnag", package: "bugsnag-cocoa"),
    .product(name: "Sentry", package: "sentry-cocoa"),
    .product(name: "Statsig", package: "statsig-kit"),
    "AppFoundation",
    "ConcurrencyFoundation",
    "FoundationInterfaces",
    "LoggingServiceInterface",
    "SettingsServiceInterface",
    "ThreadSafe",
  ],
  testsDependencies: [
    "ConcurrencyFoundation",
    "FoundationInterfaces",
    "LoggingService",
  ],
  interfaceDependencies: [
    "ConcurrencyFoundation",
    "FoundationInterfaces",
    "ThreadSafe",
  ])
