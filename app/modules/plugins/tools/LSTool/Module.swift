Target.module(
  name: "LSTool",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "ConcurrencyFoundation",
    "DLS",
    "JSONFoundation",
    "LocalServerServiceInterface",
    "ToolFoundation",
  ],
  testsDependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "JSONFoundation",
    "LocalServerServiceInterface",
    "LSTool",
    "SwiftTesting",
    "ToolFoundation",
  ])
