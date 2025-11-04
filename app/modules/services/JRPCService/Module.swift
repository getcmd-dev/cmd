Target.module(
  name: "JRPCService",
  dependencies: [
    "AppFoundation",
    "ConcurrencyFoundation",
    "DependencyFoundation",
    "JRPCServiceInterface",
    "LoggingServiceInterface",
  ],
  testsDependencies: [
    "JRPCService",
  ])
