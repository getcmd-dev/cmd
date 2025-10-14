Target.module(
  name: "CheckpointService",
  dependencies: [
    "AppFoundation",
    "CheckpointServiceInterface",
    "DependencyFoundation",
    "JSONFoundation",
    "LocalServerServiceInterface",
  ],
  testsDependencies: [],
  interfaceDependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "ConcurrencyFoundation",
  ],
  interfaceTestsDependencies: [
    "AppFoundation",
    "CheckpointServiceInterface",
    "ConcurrencyFoundation",
    "SwiftTesting",
  ])
