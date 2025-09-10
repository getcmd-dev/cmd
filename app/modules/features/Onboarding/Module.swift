Target.module(
  name: "Onboarding",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "DLS",
    "FoundationInterfaces",
    "LoggingServiceInterface",
    "PermissionsServiceInterface",
    "SettingsServiceInterface",
  ],
  resources: [.process("Resources")],
  testDependencies: [
    "FoundationInterfaces",
    "PermissionsServiceInterface",
    "SettingsServiceInterface",
    "SwiftTesting",
  ])
