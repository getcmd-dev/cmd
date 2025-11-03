Target.module(
  name: "JRPCServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "ConcurrencyFoundation",
    "LoggingServiceInterface",
    "ThreadSafe",
  ])
