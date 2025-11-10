Target.module(
  name: "XcodeControllerServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "FileDiffFoundation",
    "FileDiffTypesFoundation",
    "SettingsServiceInterface",
    "SharedValuesFoundation",
    "ThreadSafe",
  ])
