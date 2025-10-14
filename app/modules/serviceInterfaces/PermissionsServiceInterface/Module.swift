Target.module(
  name: "PermissionsServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "ConcurrencyFoundation",
    "ThreadSafe",
  ],
  testDependencies: [
    "PermissionsServiceInterface",
    "SwiftTesting",
  ])
