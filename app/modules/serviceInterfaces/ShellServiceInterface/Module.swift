Target.module(
  name: "ShellServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "LoggingServiceInterface",
    "ThreadSafe",
  ],
  testDependencies: [
    "ShellServiceInterface",
  ])
