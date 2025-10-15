Target.module(
  name: "AppEventService",
  dependencies: [
    "AppEventServiceInterface",
    "DependencyFoundation",
    "LoggingServiceInterface",
    "ThreadSafe",
  ],
  interfaceDependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "ConcurrencyFoundation",
  ])
