Target.module(
  name: "CodeCompletionFeature",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "CodeCompletionFoundation",
    "CodeCompletionServiceInterface",
    "SettingsServiceInterface",
    "XcodeObserverServiceInterface",
  ])
