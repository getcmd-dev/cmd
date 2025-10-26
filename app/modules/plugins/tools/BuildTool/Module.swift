Target.module(
  name: "BuildTool",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "ConcurrencyFoundation",
    "DLS",
    "JSONFoundation",
    "LocalServerServiceInterface",
    "ToolFoundation",
    "XcodeControllerServiceInterface",
  ],
  testsDependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "BuildTool",
    "SwiftTesting",
    "ToolFoundation",
    "XcodeControllerServiceInterface",
  ])
