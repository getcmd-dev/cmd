Target.module(
  name: "PermissionsServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "ConcurrencyFoundation",
    "ThreadSafe",
  ],
  testsDependencies: [
    "PermissionsServiceInterface",
    "SwiftTesting",
  ])
