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
    isAccessibilityPermissionGranted = .init(grantedPermissions.contains(.accessibility))
    isXcodeExtensionPermissionGranted = .init(grantedPermissions.contains(.xcodeExtension))
    isPushNotificationPermissionGranted = .init(grantedPermissions.contains(.pushNotification))
  }

  public var onRequestAccessibilityPermission: (@Sendable () -> Void)?
  public var onRequestXcodeExtensionPermission: (@Sendable () -> Void)?
  public var onRequestPushNotificationPermission: (@Sendable () -> Void)?

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

    case .pushNotification:
      Task { @MainActor in
        onRequestPushNotificationPermission?()
      }
    }
  }

  public func status(for permission: Permission) -> ReadonlyCurrentValueSubject<Bool?> {
    switch permission {
    case .accessibility:
      isAccessibilityPermissionGranted.readonly(removingDuplicate: true)
    case .xcodeExtension:
      isXcodeExtensionPermissionGranted.readonly(removingDuplicate: true)
    case .pushNotification:
      isPushNotificationPermissionGranted.readonly(removingDuplicate: true)
    }
  }

  @MainActor
  public func set(permission: Permission, granted: Bool) {
    switch permission {
    case .accessibility:
      isAccessibilityPermissionGranted.send(granted)
    case .xcodeExtension:
      isXcodeExtensionPermissionGranted.send(granted)
    case .pushNotification:
      isPushNotificationPermissionGranted.send(granted)
    }
  }

  private let isAccessibilityPermissionGranted: CurrentValueSubject<Bool?, Never>

  private let isXcodeExtensionPermissionGranted: CurrentValueSubject<Bool?, Never>

  private let isPushNotificationPermissionGranted: CurrentValueSubject<Bool?, Never>

}
#endif
