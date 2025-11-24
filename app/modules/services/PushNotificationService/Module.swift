Target.module(
  name: "PushNotificationService",
  dependencies: [
    "DependencyFoundation",
    "LoggingServiceInterface",
    "PermissionsServiceInterface",
    "PushNotificationServiceInterface",
    "ThreadSafe",
  ],
  testsDependencies: [
    "PermissionsServiceInterface",
    "PushNotificationService",
    "PushNotificationServiceInterface",
    "SwiftTesting",
  ])
