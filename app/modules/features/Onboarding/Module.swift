Target.module(
  name: "Onboarding",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "DLS",
    "FoundationInterfaces",
    "LLMServiceInterface",
    "LoggingServiceInterface",
    "PermissionsServiceInterface",
    "SettingsServiceInterface",
  ],
  resources: [.process("Resources")],
  testDependencies: [
    .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
    "FoundationInterfaces",
    "LLMServiceInterface",
    "PermissionsServiceInterface",
    "SwiftTesting",
  ])
