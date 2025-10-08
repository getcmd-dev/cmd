// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation
import LoggingServiceInterface
import XPCServiceInterface

// MARK: - AppLauncherXPCService

/// XPC service implementation for AppLauncher

final class AppLauncherXPCService: NSObject, AppLauncherXPCServer, @unchecked Sendable {

  init(xcodeMonitor: XcodeActivityMonitor) {
    self.xcodeMonitor = xcodeMonitor
    super.init()
  }

  let xcodeMonitor: XcodeActivityMonitor
  weak var clientConnection: NSXPCConnection?

  let userDefaults = UserDefaults.standard
  let pastAppVersionsKeys = "pastAppVersionsKeys"

  // MARK: - AppLauncherXPCServer

  func checkVersion(_ hostVersion: String, reply: @Sendable @escaping (Bool) -> Void) {
    #if DEBUG
    logger.log("Received version check: host=\(hostVersion)")
    /// In debug, we want to reload the service for each build once.
    var pastAppVersions = userDefaults.stringArray(forKey: pastAppVersionsKeys) ?? []
    if !pastAppVersions.contains(hostVersion) {
      pastAppVersions.append(hostVersion)
      // Keep only the last 100 versions. This should avoid scaling issues where we would store an unbounded number of elements.
      // Storing several past versions instead of just the last/current one allows to have several DEBUG clients running without each of them constantly triggering a reload.
      pastAppVersions = pastAppVersions.suffix(100)
      userDefaults.set(pastAppVersions, forKey: pastAppVersionsKeys)
      logger.log("Version mismatch")
      reply(false)
    } else {
      logger.log("Version match")
      reply(true)
      pingHostApp()
    }
    #else
    let serviceVersion = Bundle.main.appLauncherVersion
    logger.log("Received version check: host=\(hostVersion), service=\(serviceVersion)")

    if hostVersion != serviceVersion {
      logger.log("Version mismatch")
      reply(false)
    } else {
      logger.log("Version match")
      reply(true)
      pingHostApp()
    }
    #endif
  }

  func pingHostApp() {
    Task {
      let id = UUID().uuidString
      logger.log("Sending ping \(id)")
      do {
        try await clientConnection.send(to: HostAppXPCServer.self) { [weak self] connection, continuation in
          connection.ping(id: id) { [weak self] response in
            if response == id {
              self?.logger.log("Received ping response \(id)")
            } else {
              self?.logger.error("Received different ping response. Expected \(id), got \(response)")
            }
            continuation.resume()
          }
        }
      } catch { }
    }
  }

  func terminate(statusCode: Int32, reply: @escaping @Sendable (Bool) -> Void) {
    reply(true)
    exit(statusCode)
  }

  func ping(id: String, reply: @escaping @Sendable (String) -> Void) {
    logger.log("Received ping request \(id)")
    reply(id)
    logger.log("Responded to ping request \(id)")
  }

  private let logger = defaultLogger.subLogger(subsystem: "xpc")

}
