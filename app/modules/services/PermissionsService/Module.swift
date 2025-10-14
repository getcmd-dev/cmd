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
  testDependencies: [
    "ConcurrencyFoundation",
    "PermissionsService",
    "ShellServiceInterface",
    "SwiftTesting",
  ])
