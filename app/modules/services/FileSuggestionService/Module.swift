Target.module(
  name: "FileSuggestionService",
  dependencies: [
    .product(name: "Ifrit", package: "Ifrit"),
    "AppFoundation",
    "ConcurrencyFoundation",
    "DependencyFoundation",
    "FileSuggestionServiceInterface",
    "ThreadSafe",
    "XcodeObserverServiceInterface",
  ],
  testDependencies: [
    "ConcurrencyFoundation",
    "FileSuggestionService",
    "SwiftTesting",
    "XcodeObserverServiceInterface",
  ])
