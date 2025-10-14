Target.module(
  name: "FoundationInterfaces",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "ConcurrencyFoundation",
    "DependencyFoundation",
    "JSONFoundation",
    "ThreadSafe",
  ],
  testsDependencies: [])
