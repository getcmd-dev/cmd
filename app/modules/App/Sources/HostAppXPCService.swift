// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Combine
import ConcurrencyFoundation
import Foundation
import LoggingServiceInterface
import XPCServiceInterface

// MARK: - HostAppXPCService

/// Connection for communicating with the AppLauncher XPC service
public final class HostAppXPCService: NSObject, @unchecked Sendable {
  public override init() {
    super.init()
  }

  /// Connect to the AppLauncher service, and ensure that it is up to date.
  public func connect() async throws {
    try await connectUntilReady(retryCount: 0)
  }

  private var connection: NSXPCConnection?
  private let logger = defaultLogger.subLogger(subsystem: "xpc")

  /// Check if service version matches host version
  private func checkVersion() async throws {
    let hostVersion = Bundle.main.appLauncherVersion
    logger.log("Checking version: host=\(hostVersion)")

    try await connection.send(to: AppLauncherXPCServer.self) { [weak self] connection, continuation in
      connection.checkVersion(hostVersion) { [weak self] matches in
        if matches {
          self?.logger.log("Service version matches host version `\(hostVersion)`")
          continuation.resume()
        } else {
          self?.logger.log("Service version mismatch")
          continuation.resume(throwing: XPCError.versionMismatch)
        }
      }
    }
  }

  /// Disconnect from the AppLauncher service
  private func disconnect() {
    logger.log("Disconnecting from AppLauncher XPC service")
    connection?.invalidate()
    connection = nil
  }

  private func terminate(statusCode: Int32 = 0) async throws {
    logger.log("Terminating AppLauncher XPC service")
    try await connection.send(to: AppLauncherXPCServer.self) { [weak self] connection, continuation in
      connection.terminate(statusCode: statusCode, reply: { _ in })
      self?.disconnect()
      continuation.resume()
    }
  }

  /// Ping the service
  private func ping() async throws {
    let id = UUID().uuidString
    logger.log("Sending ping \(id)")
    return try await connection.send(to: AppLauncherXPCServer.self) { [weak self] connection, continuation in
      connection.ping(id: id) { [weak self] response in
        if response == id {
          self?.logger.log("Received ping response \(id)")
        } else {
          self?.logger.error("Received different ping response. Expected \(id), got \(response)")
        }
        continuation.resume()
      }
    }
  }

  private func connectUntilReady(retryCount: Int) async throws {
    guard retryCount < 5 else {
      throw AppError("Could not connect to app launcher")
    }
    do {
      if retryCount > 0 {
        logger.log("Retrying connection to AppLauncher XPC service (attempt #\(retryCount + 1))")
      }
      try await connectOnce()
    } catch XPCError.versionMismatch {
      throw XPCError.versionMismatch
    } catch {
      try await Task.sleep(nanoseconds: UInt64(1_000_000_000 * retryCount))
      try await connectUntilReady(retryCount: retryCount + 1)
    }
  }

  /// Connect to the AppLauncher service
  private func connectOnce() async throws {
    logger.log("Connecting to AppLauncher XPC service")

    let serviceName = Bundle.main.appLauncherBundleId
    logger.log("Service name: \(serviceName)")

    let connection = NSXPCConnection(machServiceName: serviceName, options: [])
    connection.remoteObjectInterface = NSXPCInterface(with: AppLauncherXPCServer.self)
    connection.exportedInterface = NSXPCInterface(with: HostAppXPCServer.self)
    connection.exportedObject = self

    let (future, continuation) = Future<Void, Error>.makeRacingContinuations()

    connection.invalidationHandler = { [weak self] in
      self?.logger.log("XPC connection invalidated")
      self?.connection = nil
      continuation.resume(throwing: AppError("XPC connection invalidated"))
    }

    connection.interruptionHandler = { [weak self] in
      self?.logger.log("XPC connection interrupted")
      self?.connection = nil
      continuation.resume(throwing: AppError("XPC connection interrupted"))
    }

    connection.resume()
    self.connection = connection

    logger.log("XPC connection established")

    // Check version immediately after connecting
    do {
      try await checkVersion()
      try await ping()
      continuation.resume()
    } catch {
      logger.error("Validating connection failed", error)
      self.connection = nil
      continuation.resume(throwing: error)
    }
    try await future.value
  }

}

// MARK: HostAppXPCServer

extension HostAppXPCService: HostAppXPCServer {
  public func ping(id: String, reply: @Sendable @escaping (String) -> Void) {
    defaultLogger.log("Received ping request \(id)")
    reply(id)
    defaultLogger.log("Responded to ping request \(id)")
  }
}
