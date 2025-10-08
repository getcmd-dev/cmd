// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import AppKit
import Foundation
import LoggingServiceInterface
import XPCServiceInterface

// MARK: - AppLauncher

public struct AppLauncher {
  public init() { }

  @MainActor
  public func main() {
    defaultLogger.log("Starting AppLauncher process with version \(Bundle.main.appLauncherVersion)")

    let serviceIdentifier = Bundle.main.appLauncherBundleId

    // Create the shared XPC service and Xcode monitor
    let xcodeMonitor = XcodeActivityMonitor(userDefaults: scope.sharedUserDefaults)
    let xpcService = AppLauncherXPCService(xcodeMonitor: xcodeMonitor)

    let appDelegate = AppDelegate()
    let delegate = ServiceDelegate(xpcService: xpcService)

    defaultLogger.log("Creating XPC listener for mach service: \(serviceIdentifier)")
    let listener = NSXPCListener(machServiceName: serviceIdentifier)
    listener.delegate = delegate
    listener.resume()
    defaultLogger.log("XPC listener resumed and ready for connections")

    // Start monitoring Xcode
    xcodeMonitor.startMonitoring()

    // Store objects in appDelegate to keep them alive
    appDelegate.xcodeMonitor = xcodeMonitor
    appDelegate.xpcService = xpcService
    appDelegate.serviceDelegate = delegate
    appDelegate.listener = listener

    let app = NSApplication.shared
    app.delegate = appDelegate

    defaultLogger.log("AppLauncher fully initialized and running")
    app.run()
  }

  let scope = AppLauncherScope.shared

}

// MARK: - ServiceDelegate

class ServiceDelegate: NSObject, NSXPCListenerDelegate {
  init(xpcService: AppLauncherXPCService) {
    self.xpcService = xpcService
  }

  let xpcService: AppLauncherXPCService

  func listener(_: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
    defaultLogger.log("Received new XPC connection request")

    // Set up the connection
    newConnection.exportedInterface = NSXPCInterface(with: AppLauncherXPCServer.self)
    newConnection.exportedObject = xpcService
    newConnection.remoteObjectInterface = NSXPCInterface(with: HostAppXPCServer.self)

    newConnection.invalidationHandler = {
      defaultLogger.log("XPC connection invalidated")
    }

    newConnection.interruptionHandler = {
      defaultLogger.log("XPC connection interrupted")
    }

    // Store the connection for callbacks
    xpcService.clientConnection = newConnection

    newConnection.resume()
    defaultLogger.log("Accepted and resumed XPC connection")
    return true
  }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
  // Retain these objects for the lifetime of the app
  var xcodeMonitor: XcodeActivityMonitor?
  var xpcService: AppLauncherXPCService?
  var serviceDelegate: ServiceDelegate?
  var listener: NSXPCListener?

  func applicationDidFinishLaunching(_: Notification) {
    defaultLogger.log("Application did finish launching")
  }

  func applicationWillTerminate(_: Notification) {
    defaultLogger.log("Application will terminate")
  }
}
