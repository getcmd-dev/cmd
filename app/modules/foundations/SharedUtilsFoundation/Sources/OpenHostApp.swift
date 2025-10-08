// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import LoggingServiceInterface

// MARK: - OpenHostApp

public enum OpenHostApp {

  // TODO: make this async and wait for the process to be running

  /// Open the host app if it is not already running, without activating it.
  public static func openHostApp(errorHandler: (String) -> any Error) throws {
    guard let hostAppBundleIdentifier = Bundle.main.object(forInfoDictionaryKey: "HOST_APP_BUNDLE_IDENTIFIER") as? String else {
      let errorMessage = "Could not read `HOST_APP_BUNDLE_IDENTIFIER` from the plist."
      defaultLogger.error(errorMessage)
      throw errorHandler(errorMessage)
    }

    // Check if the host app is already running
    let runningApps = NSWorkspace.shared.runningApplications
    let isHostAppRunning = runningApps.contains { app in
      app.bundleIdentifier == hostAppBundleIdentifier
    }
    if isHostAppRunning {
      defaultLogger.log("Host app is already running, skipping launch")
      return
    }

    // Open the app without activating it
    let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: hostAppBundleIdentifier)
    guard let appURL else {
      let errorMessage = "command could not be located in the Applications folder."
      defaultLogger.error(errorMessage)
      throw errorHandler(errorMessage)
    }
    defaultLogger.info("Opening command")

    let url = URL(fileURLWithPath: appURL.path, isDirectory: true)
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    NSWorkspace.shared.openApplication(at: url, configuration: configuration, completionHandler: nil)
  }

}

extension String {
  /// The key in user defaults where the user preference for launching the host app when Xcode activates is stored.
  public static let launchHostAppWhenXcodeDidActivate = "launchHostAppWhenXcodeDidActivate"
}
