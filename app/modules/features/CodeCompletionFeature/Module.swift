Target.module(
  name: "CodeCompletionFeature",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AccessibilityFoundation",
    "AccessibilityObjCFoundation",
    "CodeCompletionFoundation",
    "CodeCompletionServiceInterface",
    "DLS",
    "FoundationInterfaces",
    "LoggingServiceInterface",
    "RoutingFoundation",
    "SettingsServiceInterface",
    "XcodeObserverServiceInterface",
    "XcodeObserverWindowsAdapter",
  ])
