Target.module(
  name: "AppUpdateServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "ConcurrencyFoundation",
    "ThreadSafe",
  ],
  testsDependencies: [
    "AppUpdateServiceInterface",
    "SwiftTesting",
  ])
