Target.module(
  name: "GithubCopilotServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "CodeCompletionFoundation",
    "CodeCompletionServiceInterface",
    "ConcurrencyFoundation",
    "DependencyFoundation",
    "SharedValuesFoundation",
    "ThreadSafe",
  ])
