// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import Foundation

// MARK: - PushNotificationAction

public struct PushNotificationAction: Sendable, Equatable {
  public let title: String
  public let callback: @Sendable () async -> Void

  /// Internal identifier used by the service implementation. Do not use directly.
  public let identifier: String

  public init(title: String, callback: @escaping @Sendable () async -> Void) {
    self.title = title
    self.callback = callback
    identifier = UUID().uuidString
  }

  public static func ==(lhs: PushNotificationAction, rhs: PushNotificationAction) -> Bool {
    lhs.identifier == rhs.identifier
  }
}

// MARK: - PushNotification

public struct PushNotification: Sendable, Identifiable, Equatable {
  public init(
    title: String,
    body: String,
    actions: [PushNotificationAction] = [],
    onDismissed: (@Sendable () async -> Void)? = nil,
    onNotShown: (@Sendable () async -> Void)? = nil)
  {
    id = UUID().uuidString
    self.title = title
    self.body = body
    self.actions = actions
    self.onDismissed = onDismissed
    self.onNotShown = onNotShown
  }

  public let id: String
  public let title: String
  public let body: String
  public let actions: [PushNotificationAction]
  public let onDismissed: (@Sendable () async -> Void)?
  public let onNotShown: (@Sendable () async -> Void)?

  public static func ==(lhs: PushNotification, rhs: PushNotification) -> Bool {
    lhs.id == rhs.id
  }
}

// MARK: - PushNotificationService

public protocol PushNotificationService: Sendable {
  /// Send a notification.
  func send(_ notification: PushNotification) async throws

  /// Get the number of active notifications.
  func activeNotificationCount() -> ReadonlyCurrentValueSubject<Int>

  /// Get all active notifications.
  func activeNotifications() -> ReadonlyCurrentValueSubject<[PushNotification]>

  /// Clear all notifications.
  func clearAllNotifications() /// Clear a specific notification.
    async

  func clear(notification: PushNotification) async
}

// MARK: - PushNotificationServiceProviding

public protocol PushNotificationServiceProviding {
  var pushNotificationService: PushNotificationService { get }
}
