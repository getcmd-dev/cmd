Target.module(
  name: "ClaudeCodeTools",
  dependencies: [
    .product(name: "JSONScanner", package: "JSONScanner"),
    "AppFoundation",
    "ChatFoundation",
    "ConcurrencyFoundation",
    "DLS",
    "JSONFoundation",
    "ToolFoundation",
  ],
  testDependencies: [
    "ChatFoundation",
    "JSONFoundation",
    "SwiftTesting",
    "ToolFoundation",
  ])
