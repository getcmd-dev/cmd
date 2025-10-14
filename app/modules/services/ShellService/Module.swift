Target.module(
  name: "ShellService",
  dependencies: [
    .product(name: "Subprocess", package: "swift-subprocess"),
    "ConcurrencyFoundation",
    "DependencyFoundation",
    "LoggingServiceInterface",
    "ShellServiceInterface",
    "ThreadSafe",
  ],
  testsDependencies: [
    "ShellService",
  ],
  interfaceDependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "LoggingServiceInterface",
    "ThreadSafe",
  ])
