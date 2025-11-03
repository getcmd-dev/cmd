Target.module(
  name: "CodeCompletionFeature",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "CodeCompletionFeatureInterface",
    "CodeCompletionFoundation",
    "CodeCompletionServiceInterface",
    "SettingsServiceInterface",
    "XcodeObserverServiceInterface",
  ])
