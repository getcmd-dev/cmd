Target.module(
  name: "PermissionsService",
  dependencies: [
    "AppFoundation",
    "ConcurrencyFoundation",
    "DependencyFoundation",
    "LoggingServiceInterface",
    "PermissionsServiceInterface",
    "ShellServiceInterface",
    "ThreadSafe",
  ],
  testsDependencies: [
    "ConcurrencyFoundation",
    "PermissionsService",
    "ShellServiceInterface",
    "SwiftTesting",
  ],
  interfaceDependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "ConcurrencyFoundation",
    "ThreadSafe",
  ],
  interfaceTestsDependencies: [
    "PermissionsServiceInterface",
    "SwiftTesting",
  ])
