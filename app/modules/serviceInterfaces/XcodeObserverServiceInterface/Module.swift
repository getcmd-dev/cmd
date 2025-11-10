Target.module(
  name: "XcodeObserverServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AccessibilityFoundation",
    "AppFoundation",
    "ConcurrencyFoundation",
    "FoundationInterfaces",
    "LoggingServiceInterface",
    "ThreadSafe",
  ],
  testsDependencies: [
    "XcodeObserverServiceInterface",
  ])
