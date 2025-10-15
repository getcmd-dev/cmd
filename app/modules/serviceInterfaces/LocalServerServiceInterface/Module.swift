Target.module(
  name: "LocalServerServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "ConcurrencyFoundation",
    "JSONFoundation",
  ],
  testsDependencies: [
    "AppFoundation",
    "ConcurrencyFoundation",
    "LocalServerServiceInterface",
    "SwiftTesting",
  ])
