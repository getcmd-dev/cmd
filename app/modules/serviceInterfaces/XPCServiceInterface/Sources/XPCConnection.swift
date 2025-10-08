// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - AppLauncherXPCServer

/// The server interface for the app launcher XPC service
@objc
public protocol AppLauncherXPCServer {
  /// Check that the version used by the app launcher matches the client's one.
  func checkVersion(_ clientVersion: String, reply: @Sendable @escaping (Bool) -> Void)

  /// Ask the service to terminate. If the status code is non-zero, the service will be automatically restarted by launchd
  func terminate(statusCode: Int32, reply: @Sendable @escaping (Bool) -> Void)

  /// Ping the app launcher to check if it's connected
  func ping(id: String, reply: @Sendable @escaping (String) -> Void)
}

// MARK: - HostAppXPCServer

/// The server interface for the host app XPC service
@objc
public protocol HostAppXPCServer {
  /// Ping the app to check if it's connected
  func ping(id: String, reply: @Sendable @escaping (String) -> Void)
}
