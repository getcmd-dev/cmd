// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import ThreadSafe

#if DEBUG
@ThreadSafe
public final class MockPushNotificationService: PushNotificationService {

  public init() { }

  public var onSend: (@Sendable (PushNotification) async throws -> Void)?
  public var onHandleActionCallback: (@Sendable (String) async -> Void)?
  public var onHandleTapped: (@Sendable (String) async -> Void)?
  public var onClearAllNotifications: (@Sendable () async -> Void)?
  public var onClear: (@Sendable (PushNotification) async -> Void)?

  public func send(_ notification: PushNotification) async throws {
    if let onSend {
      try await onSend(notification)
    }
    notifications.send(notifications.value + [notification])
  }

  /// Internal method for handling action callbacks (not part of public protocol)
  public func handleActionCallback(actionIdentifier: String) async {
    if let onHandleActionCallback {
      await onHandleActionCallback(actionIdentifier)
    }
    let callback = notifications.value.first(where: { $0.actions.contains(where: { $0.identifier == actionIdentifier }) })?
      .actions.first(where: { $0.identifier == actionIdentifier })?.callback
    if let callback {
      await callback()
    }
  }

  /// Internal method for handling notification taps (not part of public protocol)
  public func handleTapped(notificationId: String) async {
    if let onHandleTapped {
      await onHandleTapped(notificationId)
    }
    let notification = notifications.value.first(where: { $0.id == notificationId })
    if let notification, let onTapped = notification.onTapped {
      await onTapped()
    }
    // Remove notification after being tapped
    notifications.send(notifications.value.filter { $0.id != notificationId })
  }

  public func activeNotificationCount() -> ReadonlyCurrentValueSubject<Int> {
    .init(notifications.value.count, publisher: notifications.map(\.count).removeDuplicates().eraseToAnyPublisher())
  }

  public func activeNotifications() -> ReadonlyCurrentValueSubject<[PushNotification]> {
    notifications.readonly()
  }

  public func clearAllNotifications() async {
    if let onClearAllNotifications {
      await onClearAllNotifications()
    }
    notifications.send([])
  }

  public func clear(notification: PushNotification) async {
    if let onClear {
      await onClear(notification)
    }
    notifications.send(notifications.value.filter { $0 != notification })
  }

  private let notifications = CurrentValueSubject<[PushNotification], Never>([])
}
#endif
