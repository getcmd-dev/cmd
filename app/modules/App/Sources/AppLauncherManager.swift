// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import FoundationInterfaces
import LoggingServiceInterface
import ServiceManagement

// MARK: - AppLauncherManager

/// Manages the launch agent registration with launchd.
/// This allows a background helper process to run at login and provide services.
/// The launch agent can be communicated with via XPC.
public struct AppLauncherManager: Sendable {
  public init(userDefaults: UserDefaultsI) {
    self.userDefaults = userDefaults
  }

  /// The current status of the launch agent.
  public var status: SMAppService.Status {
    service.status
  }

  /// Registers the launch agent to run at login if it hasn't already been registered.
  public func enable() async throws {
    if service.status == .enabled {
      do {
        // Validate connection and return. This will ensure that the service is running the correct version.
        try await xpcClient.connect()
        return
      } catch {
        // The connection could not be established, unregister.
        do {
          defaultLogger.log("Unregistering launch agent that could not be connected to")
          try await service.unregister()
        } catch {
          defaultLogger.error("Failed to unregister unresponsive launch agent", error)
        }
      }
    }

    // Register the service
    do {
      try service.register()
      try await xpcClient.connect()
      defaultLogger.log("Launch agent enabled successfully")
    } catch {
      defaultLogger.error("Failed to enable launch agent", error)
      throw error
    }
  }

  private let userDefaults: UserDefaultsI
  private let xpcClient = HostAppXPCService()

  private var service: SMAppService {
    SMAppService.agent(plistName: "appLauncher.plist")
  }
}
