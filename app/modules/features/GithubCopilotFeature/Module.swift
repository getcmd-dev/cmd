Target.module(
  name: "GithubCopilotFeature",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "DLS",
    "GithubCopilotFeatureInterface",
    "GithubCopilotServiceInterface",
    "RoutingFoundation",
  ])
