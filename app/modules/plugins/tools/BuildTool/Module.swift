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
    "AppFoundation",
    "SwiftTesting",
    "ToolFoundation",
    "XcodeControllerServiceInterface",
  ])
