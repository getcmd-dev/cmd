// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import DependencyFoundation
import Foundation
import LoggingServiceInterface
import PermissionsServiceInterface
import PushNotificationServiceInterface
import ThreadSafe
import UserNotifications

// MARK: - DefaultPushNotificationService

@ThreadSafe
final class DefaultPushNotificationService: NSObject, PushNotificationService, UNUserNotificationCenterDelegate {

  init(
    notificationCenter: UNUserNotificationCenter,
    permissionsService: PermissionsService)
  {
    self.notificationCenter = notificationCenter
    self.permissionsService = permissionsService
    super.init()
    notificationCenter.delegate = self
  }

  func send(_ notification: PushNotification) async throws {
    // Check if we have permission
    let hasPermission = permissionsService.status(for: .pushNotification).currentValue.isGranted
    if !hasPermission {
      defaultLogger.info("Push notification permission not granted. Cannot send notification.")
      throw PushNotificationError.permissionNotGranted
    }

    // Create notification content
    let content = UNMutableNotificationContent()
    content.title = notification.title
    content.body = notification.body
    content.sound = .none

    // Set up category (even if no actions, to keep notification persistent)
    let notificationActions: [UNNotificationAction] =
      if !notification.actions.isEmpty {
        notification.actions.map { action in
          UNNotificationAction(
            identifier: action.identifier,
            title: action.title,
            options: [])
        }
      } else {
        []
      }

    let category = UNNotificationCategory(
      identifier: "CMD_NOTIFICATION_CATEGORY",
      actions: notificationActions,
      intentIdentifiers: [],
      options: [])
    notificationCenter.setNotificationCategories([category])
    content.categoryIdentifier = "CMD_NOTIFICATION_CATEGORY"

    // Store action callbacks mapped to notification ID

    inLock { state in
      state.notificationIdMapping[notification.id] = notification
      if !notification.actions.isEmpty {
        for action in notification.actions {
          state.actionCallbacks[action.identifier] = action.callback
        }
      }
    }

    // Create request with the notification's ID
    let request = UNNotificationRequest(
      identifier: notification.id,
      content: content,
      trigger: nil) // nil trigger means show immediately

    do {
      // Send notification
      try await notificationCenter.add(request)

      // Update the notifications subject
      _notifications.send(_notifications.value + [notification])
    } catch {
      clear(notification: notification)
      throw error
    }
  }

  /// Internal method for handling action callbacks (not part of public protocol)
  func handleActionCallback(actionIdentifier: String) async {
    if let callback = actionCallbacks[actionIdentifier] {
      await callback()
    } else {
      defaultLogger.info("No callback found for action identifier: \(actionIdentifier)")
    }
  }

  func activeNotificationCount() -> ReadonlyCurrentValueSubject<Int> {
    .init(0, publisher: _notifications.map(\.count).eraseToAnyPublisher())
  }

  func activeNotifications() -> ReadonlyCurrentValueSubject<[PushNotification]> {
    _notifications.readonly()
  }

  func clearAllNotifications() async {
    notificationCenter.removeAllDeliveredNotifications()
    inLock { state in
      state.actionCallbacks.removeAll()
      state.notificationIdMapping.removeAll()
    }
    _notifications.send([])
  }

  func clear(notification: PushNotification) {
    notificationCenter.removeDeliveredNotifications(withIdentifiers: [notification.id])
    inLock { state in
      state.notificationIdMapping.removeValue(forKey: notification.id)
      // Remove callbacks for this notification's actions
      for action in notification.actions {
        state.actionCallbacks.removeValue(forKey: action.identifier)
      }
    }
    _notifications.send(_notifications.value.filter { $0.id != notification.id })
  }

  // MARK: - UNUserNotificationCenterDelegate

  func userNotificationCenter(
    _: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void)
  {
    let notificationId = response.notification.request.identifier
    let actionIdentifier = response.actionIdentifier

    // Call completion handler immediately
    completionHandler()

    // Handle callbacks asynchronously
    Task {
      // Handle notification tap (default action)
      if actionIdentifier == UNNotificationDefaultActionIdentifier {
        await handleTapped(notificationId: notificationId)
      }
      // Handle action button callback
      else if actionIdentifier != UNNotificationDismissActionIdentifier {
        await handleActionCallback(actionIdentifier: actionIdentifier)
      }

      // Handle dismissal callback
      if actionIdentifier == UNNotificationDismissActionIdentifier {
        await handleDismissed(notificationId: notificationId)
      }
    }
  }

  func userNotificationCenter(
    _: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
  {
    let notificationId = notification.request.identifier
    completionHandler([.banner, .list])

    // Call the onNotShown callback asynchronously
    Task {
      await handleNotShown(notificationId: notificationId)
    }
  }

  private let _notifications = CurrentValueSubject<[PushNotification], Never>([])

  nonisolated(unsafe) private let notificationCenter: UNUserNotificationCenter
  private let permissionsService: PermissionsService
  private var actionCallbacks = [String: @Sendable () async -> Void]()
  private var notificationIdMapping = [String: PushNotification]()

  private func handleDismissed(notificationId: String) async {
    let notification: PushNotification? = inLock { state in
      if let notification = state.notificationIdMapping.removeValue(forKey: notificationId) {
        for action in notification.actions {
          state.actionCallbacks.removeValue(forKey: action.identifier)
        }
        return notification
      }
      return nil
    }

    if let notification, let onDismissed = notification.onDismissed {
      await onDismissed()
    }

    // Remove from active notifications
    _notifications.send(_notifications.value.filter { $0.id != notificationId })
  }

  private func handleNotShown(notificationId: String) async {
    let notification = notificationIdMapping[notificationId]

    if let notification, let onNotShown = notification.onNotShown {
      await onNotShown()
    }
  }

  private func handleTapped(notificationId: String) async {
    let notification: PushNotification? = inLock { state in
      if let notification = state.notificationIdMapping.removeValue(forKey: notificationId) {
        for action in notification.actions {
          state.actionCallbacks.removeValue(forKey: action.identifier)
        }
        return notification
      }
      return nil
    }

    if let notification, let onTapped = notification.onTapped {
      await onTapped()
    }

    // Remove from active notifications after being tapped
    _notifications.send(_notifications.value.filter { $0.id != notificationId })
  }
}

// MARK: - PushNotificationError

enum PushNotificationError: Error {
  case permissionNotGranted
}

// MARK: - BaseProviding Extension

extension BaseProviding where
  Self: PermissionsServiceProviding
{
  public var pushNotificationService: PushNotificationService {
    shared {
      DefaultPushNotificationService(
        notificationCenter: .current(),
        permissionsService: permissionsService)
    }
  }
}
