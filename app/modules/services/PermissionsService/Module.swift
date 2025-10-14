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
  ])
