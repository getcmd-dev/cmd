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
  testsDependencies: [
    "ConcurrencyFoundation",
    "FileSuggestionService",
    "SwiftTesting",
    "XcodeObserverServiceInterface",
  ],
  interfaceDependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "ThreadSafe",
  ])
