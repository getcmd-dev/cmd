Target.module(
  name: "PermissionsService",
  dependencies: [
    "AppFoundation",
    "ConcurrencyFoundation",
    "DependencyFoundation",
    "FoundationInterfaces",
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
