// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies

// MARK: - PushNotificationServiceDependencyKey

public final class PushNotificationServiceDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: PushNotificationService = MockPushNotificationService()
  #else
  public static let testValue: PushNotificationService = () as! PushNotificationService
  #endif
}

extension DependencyValues {
  public var pushNotificationService: PushNotificationService {
    get { self[PushNotificationServiceDependencyKey.self] }
    set { self[PushNotificationServiceDependencyKey.self] = newValue }
  }
}
