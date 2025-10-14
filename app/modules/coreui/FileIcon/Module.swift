Target.module(
  name: "FileIcon",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppFoundation",
    "ConcurrencyFoundation",
    "DLS",
    "FoundationInterfaces",
    "LocalServerServiceInterface",
    "ShellServiceInterface",
  ],
  resources: [
    .process("Resources/fileIcons"),
  ])
