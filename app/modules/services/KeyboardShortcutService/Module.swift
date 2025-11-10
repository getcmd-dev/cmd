Target.module(
  name: "KeyboardShortcutService",
  dependencies: [
    .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
    "DependencyFoundation",
    "KeyboardShortcutServiceInterface",
    "LoggingServiceInterface",
    "ThreadSafe",
    "XcodeObserverServiceInterface",
  ])
