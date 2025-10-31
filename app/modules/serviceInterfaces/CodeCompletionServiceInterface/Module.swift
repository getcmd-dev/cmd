Target.module(
  name: "CodeCompletionServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "CodeCompletionFoundation",
    "ThreadSafe",
    "XcodeObserverServiceInterface",
  ])
