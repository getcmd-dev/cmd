Target.module(
  name: "AppUpdateServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "ConcurrencyFoundation",
    "ThreadSafe",
  ],
  testDependencies: [
    "AppUpdateServiceInterface",
    "SwiftTesting",
  ])
