Target.module(
  name: "BuildTool",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "CodePreview",
    "ConcurrencyFoundation",
    "DLS",
    "JSONFoundation",
    "LocalServerServiceInterface",
    "ToolFoundation",
    "XcodeControllerServiceInterface",
  ],
  testDependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "BuildTool",
    "SwiftTesting",
    "ToolFoundation",
    "XcodeControllerServiceInterface",
  ])
