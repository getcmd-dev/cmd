Target.module(
  name: "HighlighterServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    .product(name: "HighlightSwift", package: "highlightswift"),
    "AppFoundation",
    "DependencyFoundation",
  ])
