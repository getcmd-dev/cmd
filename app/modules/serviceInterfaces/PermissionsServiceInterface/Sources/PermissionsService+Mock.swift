// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import ThreadSafe

#if DEBUG
@ThreadSafe
public final class MockPermissionsService: PermissionsService {

  public init(grantedPermissions: [Permission] = []) {
    isAccessibilityPermissionGranted = .init(grantedPermissions.contains(.accessibility) ? .grantedEnabled : .notGranted)
    isXcodeExtensionPermissionGranted = .init(grantedPermissions.contains(.xcodeExtension) ? .grantedEnabled : .notGranted)
    isXcodeAutomationPermissionGranted = .init(grantedPermissions.contains(.xcodeAutomation) ? .grantedEnabled : .notGranted)
    isPushNotificationPermissionGranted = .init(grantedPermissions.contains(.pushNotification) ? .grantedEnabled : .notGranted)
  }

  public var onRequestAccessibilityPermission: (@Sendable () -> Void)?
  public var onRequestXcodeExtensionPermission: (@Sendable () -> Void)?
  public var onRequestXcodeAutomationPermission: (@Sendable () -> Void)?
  public var onRequestPushNotificationPermission: (@Sendable () -> Void)?
  public var onEnablePushNotifications: (@Sendable () -> Void)?
  public var onDisablePushNotifications: (@Sendable () -> Void)?

  public func request(permission: Permission) {
    switch permission {
    case .accessibility:
      Task { @MainActor in
        onRequestAccessibilityPermission?()
      }

    case .xcodeExtension:
      Task { @MainActor in
        onRequestXcodeExtensionPermission?()
      }

    case .xcodeAutomation:
      Task { @MainActor in
        onRequestXcodeAutomationPermission?()
      }

    case .pushNotification:
      Task { @MainActor in
        onRequestPushNotificationPermission?()
      }
    }
  }

  public func status(for permission: Permission) -> ReadonlyCurrentValueSubject<PermissionStatus> {
    switch permission {
    case .accessibility:
      isAccessibilityPermissionGranted.readonly(removingDuplicate: true)
    case .xcodeExtension:
      isXcodeExtensionPermissionGranted.readonly(removingDuplicate: true)
    case .xcodeAutomation:
      isXcodeAutomationPermissionGranted.readonly(removingDuplicate: true)
    case .pushNotification:
      isPushNotificationPermissionGranted.readonly(removingDuplicate: true)
    }
  }

  public func enablePushNotifications() {
    onEnablePushNotifications?()
  }

  public func disablePushNotifications() {
    onDisablePushNotifications?()
  }

  @MainActor
  public func set(permission: Permission, status: PermissionStatus) {
    switch permission {
    case .accessibility:
      isAccessibilityPermissionGranted.send(status)
    case .xcodeExtension:
      isXcodeExtensionPermissionGranted.send(status)
    case .xcodeAutomation:
      isXcodeAutomationPermissionGranted.send(status)
    case .pushNotification:
      isPushNotificationPermissionGranted.send(status)
    }
  }

  private let isAccessibilityPermissionGranted: CurrentValueSubject<PermissionStatus, Never>

  private let isXcodeExtensionPermissionGranted: CurrentValueSubject<PermissionStatus, Never>

  private let isXcodeAutomationPermissionGranted: CurrentValueSubject<PermissionStatus, Never>

  private let isPushNotificationPermissionGranted: CurrentValueSubject<PermissionStatus, Never>

}
#endif
