Target.module(
  name: "LoggingService",
  dependencies: [
    .product(name: "Sentry", package: "sentry-cocoa"),
    .product(name: "Statsig", package: "statsig-kit"),
    "ConcurrencyFoundation",
    "FoundationInterfaces",
    "LoggingServiceInterface",
    "ThreadSafe",
  ],
  testDependencies: [])
