Target.module(
  name: "InlineChatFeature",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "AppEventServiceInterface",
    "ChatAppEventsFoundation",
    "ChatHistoryServiceInterface",
    "ChatInput",
    "DLS",
    "FileDiffFoundation",
    "LLMFoundation",
    "LoggingServiceInterface",
    "RoutingFoundation",
    "XcodeObserverServiceInterface",
    "XcodeObserverWindowsAdapter",
  ],
  testsDependencies: [])
