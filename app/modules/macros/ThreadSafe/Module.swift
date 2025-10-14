Target.macroModule(
  name: "ThreadSafe",
  macroDependencies: [
    .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
    .product(name: "SwiftSyntax", package: "swift-syntax"),
    .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
  ],
  dependencies: [
    .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
    .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
    "ConcurrencyFoundation",
  ],
  testsDependencies: [
    .product(name: "MacroTesting", package: "swift-macro-testing"),
    .product(name: "SwiftSyntax", package: "swift-syntax"),
    .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
    "ThreadSafeMacro",
  ])
