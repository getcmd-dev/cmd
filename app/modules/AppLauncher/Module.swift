Target.module(
  name: "AppLauncher",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "DependencyFoundation",
    "FoundationInterfaces",
    "LoggingService",
    "LoggingServiceInterface",
    "SharedUtilsFoundation",
    "ThreadSafe",
    "XPCServiceInterface",
  ])
