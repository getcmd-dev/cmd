Target.module(
  name: "MCPService",
  dependencies: [
    .product(name: "MCP", package: "swift-sdk"),
    "AppFoundation",
    "ChatFoundation",
    "DependencyFoundation",
    "FoundationInterfaces",
    "JSONFoundation",
    "LoggingServiceInterface",
    "MCPServiceInterface",
    "SettingsServiceInterface",
    "ShellServiceInterface",
    "ThreadSafe",
    "ToolFoundation",
  ],
  testDependencies: [
    "MCPServiceInterface",
    "SettingsServiceInterface",
    "SwiftTesting",
  ])
