Target.module(
  name: "PushNotificationServiceInterface",
  dependencies: [
    .product(name: "Dependencies", package: "swift-dependencies"),
    "ConcurrencyFoundation",
    "ThreadSafe",
  ],
  testsDependencies: [
    "PushNotificationServiceInterface",
    "SwiftTesting",
  ])
