Target.module(
  name: "InlineChatFeature",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppEventServiceInterface",
    "ChatAppEventsFoundation",
    "DLS",
    "FileDiffFoundation",
    "LLMFoundation",
    "LoggingServiceInterface",
    "XcodeObserverServiceInterface",
    "XcodeObserverWindowsAdapter",
  ],
  testsDependencies: [])
