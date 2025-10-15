Target.module(
  name: "ClaudeCodeTools",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    .product(name: "JSONScanner", package: "JSONScanner"),
    "AppFoundation",
    "ChatFoundation",
    "ChatServiceInterface",
    "ConcurrencyFoundation",
    "DLS",
    "FileIcon",
    "JSONFoundation",
    "ToolFoundation",
  ],
  testsDependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "ChatFoundation",
    "ClaudeCodeTools",
    "JSONFoundation",
    "SwiftTesting",
    "ToolFoundation",
  ])
