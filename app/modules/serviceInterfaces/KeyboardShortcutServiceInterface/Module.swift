Target.module(
  name: "KeyboardShortcutServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
    "ThreadSafe",
  ])
