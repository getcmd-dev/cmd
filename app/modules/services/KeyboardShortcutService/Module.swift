Target.module(
  name: "KeyboardShortcutService",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
    "AppEventServiceInterface",
    "AppFoundation",
    "ChatAppEvents",
    "DependencyFoundation",
    "KeyboardShortcutServiceInterface",
    "LoggingServiceInterface",
    "ThreadSafe",
    "XcodeObserverServiceInterface",
  ],
  testsDependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
    "ConcurrencyFoundation",
    "KeyboardShortcutService",
    "KeyboardShortcutServiceInterface",
    "ThreadSafe",
    "XcodeObserverServiceInterface",
  ])
