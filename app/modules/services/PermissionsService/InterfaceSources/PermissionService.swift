// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation

// MARK: - Permission

public enum Permission {
  case accessibility
  case xcodeExtension
}

// MARK: - PermissionsService

public protocol PermissionsService: Sendable {
  /// Prompt the user to grant the desired permission.
  func request(permission: Permission)

  /// Check if the permission is granted. The publisher will be updated as the permissions status changes.
  func status(for permission: Permission) -> ReadonlyCurrentValueSubject<Bool?, Never>
}

// MARK: - PermissionsServiceProviding

public protocol PermissionsServiceProviding {
  var permissionsService: PermissionsService { get }
}
