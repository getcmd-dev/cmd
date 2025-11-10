Target.module(
  name: "ShellService",
  dependencies: [
    .product(name: "Subprocess", package: "swift-subprocess"),
    "AppFoundation",
    "ConcurrencyFoundation",
    "DependencyFoundation",
    "LoggingServiceInterface",
    "ShellServiceInterface",
    "ThreadSafe",
  ],
  testsDependencies: [
    "ShellService",
  ])
