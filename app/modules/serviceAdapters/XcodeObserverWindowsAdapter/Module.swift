Target.module(
  name: "XcodeObserverWindowsAdapter",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AccessibilityFoundation",
    "AccessibilityObjCFoundation",
    "XcodeObserverServiceInterface",
  ])
