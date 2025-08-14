Target.module(
  name: "LocalServerServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "ConcurrencyFoundation",
    "JSONFoundation",
  ],
  testDependencies: [
    "AppFoundation",
    "ConcurrencyFoundation",
    "SwiftTesting",
  ])
