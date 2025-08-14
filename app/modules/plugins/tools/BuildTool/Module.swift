Target.module(
  name: "BuildTool",
  dependencies: [
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
    "SwiftTesting",
    "ToolFoundation",
    "XcodeControllerServiceInterface",
  ])
