// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation

// MARK: - Permission

public enum Permission {
  case accessibility
  case xcodeExtension
  case xcodeAutomation
  case pushNotification
}

// MARK: - PermissionsService

public protocol PermissionsService: Sendable {
  /// Prompt the user to grant the desired permission.
  func request(permission: Permission)

  /// Check if the permission is granted. The publisher will be updated as the permissions status changes.
  func status(for permission: Permission) -> ReadonlyCurrentValueSubject<PermissionStatus>

  func enablePushNotifications()

  func disablePushNotifications()
}

// MARK: - PermissionsServiceProviding

public protocol PermissionsServiceProviding {
  var permissionsService: PermissionsService { get }
}

// MARK: - PermissionStatus

public enum PermissionStatus: Sendable, Equatable {
  case unknown
  /// The permission has not been granted at the OS level.
  case notGranted
  /// The permission has been granted at the OS level, and is enabled at the app level.
  case grantedEnabled
  /// The permission has been granted at the OS level, but is disabled at the app level.
  case grantedDisabled

  /// Whether the permission has been granted at the OS level.
  public var isGranted: Bool {
    self == .grantedEnabled || self == .grantedDisabled
  }
}
