Target.module(
  name: "CodeCompletionServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "CodeCompletionFoundation",
    "ConcurrencyFoundation",
    "FileDiffTypesFoundation",
    "ThreadSafe",
    "XcodeObserverServiceInterface",
  ])
