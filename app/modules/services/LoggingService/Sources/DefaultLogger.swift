// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Bugsnag
import ConcurrencyFoundation
import Foundation
import FoundationInterfaces
import LoggingServiceInterface
import OSLog
import Sentry
import SettingsServiceInterface
import Statsig
import ThreadSafe

// MARK: - DefaultLogger

/// Default implementation of Logger that supports both local file logging and external service integration.
/// Provides thread-safe logging with support for multiple log levels and external services like Sentry and Statsig.
@ThreadSafe
public final class DefaultLogger: LoggingServiceInterface.Logger {
  /// Creates a logger with default configuration for local file logging only.
  /// - Parameters:
  ///   - subsystem: The subsystem identifier for the logger
  ///   - category: The category identifier for the logger
  ///   - fileManager: File manager for handling log file operations
  public convenience init(subsystem: String, category: String, fileManager: FileManagerI, userDefaults: UserDefaultsI) {
    self.init(
      subsystem: subsystem,
      category: category,
      fileManager: fileManager,
      userDefaults: userDefaults,
      is3rdPartyLoggingEnabled: false,
      writeToFile: nil)
  }

  /// Internal initializer with full configuration options.
  /// - Parameters:
  ///   - subsystem: The subsystem identifier for the logger
  ///   - category: The category identifier for the logger
  ///   - fileManager: File manager for handling log file operations
  ///   - is3rdPartyLoggingEnabled: Whether external logging services are enabled
  ///   - writeToFile: Optional custom file writing function
  private init(
    subsystem: String,
    category: String,
    fileManager: FileManagerI,
    userDefaults: UserDefaultsI,
    is3rdPartyLoggingEnabled: Bool,
    writeToFile: (@Sendable (String) -> Void)?)
  {
    logger = os.Logger(subsystem: subsystem, category: category)
    self.subsystem = subsystem
    self.category = category
    self.fileManager = fileManager
    self.userDefaults = userDefaults
    deviceId = Self.getDeviceId(userDefaults: userDefaults)
    self.is3rdPartyLoggingEnabled = is3rdPartyLoggingEnabled

    setupLocalLogFile(writeToFile: writeToFile, fileManager: fileManager)
  }

  deinit {
    logFile?.closeFile()
  }

  public let subsystem: String
  public let category: String

  /// Enables external logging services (Sentry and Statsig).
  /// This method is idempotent - calling it multiple times has no additional effect.
  public func startExternalLogging() {
    #if DEBUG
    guard userDefaults.bool(forKey: .enableAnalyticsAndCrashReporting) else { return }
    #endif

    let wasEnable = _internalState.set(\.is3rdPartyLoggingEnabled, to: true)
    guard !wasEnable else { return }
    startSentry()
    startBugSnag()
    startStatsig()
  }

  /// Disables external logging services (Sentry and Statsig).
  /// This method is idempotent - calling it multiple times has no additional effect.
  public func stopExternalLogging() {
    let wasEnable = _internalState.set(\.is3rdPartyLoggingEnabled, to: false)
    guard wasEnable else { return }
    stopSentry()
    stopBugsnag()
    stopStatsig()
  }

  /// Creates a sub-logger with an extended subsystem name.
  /// - Parameter subsystem: The subsystem name to append to the current subsystem
  /// - Returns: A new logger instance with the extended subsystem name
  public func subLogger(subsystem: String) -> LoggingServiceInterface.Logger {
    DefaultLogger(
      subsystem: "\(self.subsystem).\(subsystem)",
      category: category,
      fileManager: fileManager,
      userDefaults: userDefaults,
      is3rdPartyLoggingEnabled: is3rdPartyLoggingEnabled,
      writeToFile: writeToFile)
  }

  /// Logs a debug message to the console and file.
  /// - Parameter message: The debug message to log
  public func debug(_ message: String) {
    let formattedMessage = "[Debug] \(message)"
    logger.debug("\(formattedMessage, privacy: .public)")
    writeToFile("\(subsystem).\(category) \(formattedMessage)")
  }

  /// Logs an informational message to the console and file.
  /// - Parameter message: The informational message to log
  public func info(_ message: String) {
    let formattedMessage = "[Info] \(message)"
    logger.info("\(formattedMessage, privacy: .public)")
    writeToFile("\(subsystem).\(category) \(formattedMessage)")
  }

  /// Logs a general message to the console, file, and optionally to Sentry.
  /// - Parameter message: The message to log
  public func log(_ message: String) {
    let formattedMessage = "[Log] \(message)"
    logger.log("\(formattedMessage, privacy: .public)")
    writeToFile("\(subsystem).\(category) \(formattedMessage)")

    if is3rdPartyLoggingEnabled {
      let breadcrumb = Breadcrumb(level: .info, category: "\(subsystem):\(category)")
      breadcrumb.message = message
      SentrySDK.addBreadcrumb(breadcrumb)
    }
  }

  /// Records an event with value and optional metadata to the console, file, and optionally to Statsig.
  /// - Parameters:
  ///   - event: The event name to record
  ///   - value: The event value
  ///   - metadata: Optional metadata dictionary for the event
  public func record(event: StaticString, value: String, metadata: [StaticString: String]? = nil) {
    let formattedMessage = "[Event] \(event)"
    logger.log("\(formattedMessage, privacy: .public)")
    writeToFile("\(subsystem).\(category) \(formattedMessage)")

    if is3rdPartyLoggingEnabled {
      Statsig.logEvent(event.string, value: value, metadata: metadata?.reduce(into: [String: String]()) { acc, item in
        acc[item.key.string] = item.value
      })
    }
  }

  /// Logs a notice message to the console and file.
  /// - Parameter message: The notice message to log
  public func notice(_ message: String) {
    let formattedMessage = "[Notice] \(message)"
    logger.notice("\(formattedMessage, privacy: .public)")
    writeToFile("\(subsystem).\(category) \(formattedMessage)")
  }

  /// Logs an error message to the console, file, and optionally to Sentry.
  /// - Parameter message: The error message to log
  public func error(_ message: String) {
    let formattedMessage = "[Error] \(message)"
    logger.error("\(formattedMessage, privacy: .public)")
    writeToFile("\(subsystem).\(category) \(formattedMessage)")
    if is3rdPartyLoggingEnabled {
      SentrySDK.capture(message: formattedMessage)
      Bugsnag.notifyError(AppError(message))
    }
  }

  /// Logs an error object to the console, file, and optionally to Sentry.
  /// - Parameter error: The error object to log
  public func error(_ error: any Error) {
    self.error(nil, error)
  }

  /// Logs an error with an optional descriptive message to the console, file, and optionally to Sentry.
  /// - Parameters:
  ///   - message: Optional descriptive message for the error
  ///   - error: The error object to log
  public func error(_ message: String?, _ error: any Error) {
    let messagePrefix = message != nil ? "\(message!): " : ""
    let debugDescription = (error as CustomDebugStringConvertible).debugDescription

    if !debugDescription.isEmpty {
      let formattedMessage = "[Error] \(messagePrefix)\(error.localizedDescription)\n\ndebugDescription: \(debugDescription)"
      logger.error(
        "\(formattedMessage, privacy: .public)")
      writeToFile("\(subsystem).\(category) \(formattedMessage)")
    } else {
      let formattedMessage = "[Error] \(messagePrefix)\(error.localizedDescription)"
      logger.error("\(formattedMessage, privacy: .public)")
      writeToFile("\(subsystem).\(category) \(formattedMessage)")
    }
    if is3rdPartyLoggingEnabled {
      SentrySDK.capture(error: error)
      Bugsnag.notifyError(error)
    }
  }

  let deviceId: String

  /// Queue for handling concurrent write operations to the log file
  private let fileWriteQueue = TaskQueue<Void, any Error>()

  private let fileManager: FileManagerI

  private let userDefaults: UserDefaultsI

  private var is3rdPartyLoggingEnabled = false

  /// Current log file URL, created with timestamp for each session
  private var logFile: FileHandle?

  private let logger: os.Logger

  /// Writes a message to the log file
  private var writeToFile: (@Sendable (_ message: String) -> Void) = { _ in }

  private static func getDeviceId(userDefaults: UserDefaultsI) -> String {
    if let deviceId = userDefaults.string(forKey: "deviceId") {
      return deviceId
    } else {
      let newDeviceId = UUID().uuidString
      userDefaults.set(newDeviceId, forKey: "deviceId")
      return newDeviceId
    }
  }

  /// Sets up local file logging with automatic file creation and timestamped naming.
  /// Creates log files in the application support directory under command/logs/.
  /// - Parameters:
  ///   - writeToFile: Optional custom file writing function
  ///   - fileManager: File manager for handling file operations
  private func setupLocalLogFile(writeToFile: (@Sendable (String) -> Void)?, fileManager: FileManagerI) {
    if let writeToFile {
      self.writeToFile = writeToFile
    } else {
      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "yyyy-MM-dd__HH-mm-ss.SSS"
      dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
      let timestamp = dateFormatter.string(from: Date())

      guard let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
        return
      }
      let logDir = applicationSupport.appendingPathComponent(Bundle.main.hostAppBundleId).appendingPathComponent("logs")
      try? fileManager.createDirectory(at: logDir, withIntermediateDirectories: true)

      let logFilePath = logDir.appendingPathComponent("\(timestamp).txt")
      do {
        try fileManager.write(data: Data(), to: logFilePath)
        let logFile = try fileManager.fileHandle(forWritingTo: logFilePath)
        let writeToFile: (@Sendable (String) -> Void) = { [weak self] message in
          let formattedMessage = "\(Date().ISO8601Format()) \(message)\n"
          guard let self, let data = formattedMessage.data(using: .utf8) else { return }
          fileWriteQueue.queue {
            logFile.write(data)
          }
        }

        inLock { state in
          state.logFile = logFile
          state.writeToFile = writeToFile
        }
      } catch {
        self.error("Error creating log file", error)
      }
    }
  }

  /// Initializes Sentry SDK for error tracking and reporting.
  private func startSentry() {
    SentrySDK.start { options in
      options.dsn = "https://010dbc05cddb56d4795120317831f881@o4509381911576576.ingest.us.sentry.io/4509381913018368"
      options.attachStacktrace = true
      options.enableWatchdogTerminationTracking = true

      // Don't adds IP for users.
      options.sendDefaultPii = false
    }
  }

  /// Shuts down Sentry SDK.
  private func stopSentry() {
    SentrySDK.close()
  }

  private func startBugSnag() {
    Bugsnag.start()
  }

  private func stopBugsnag() {
    Bugsnag.pauseSession()
  }

  /// Initializes Statsig SDK for event tracking and feature flags.
  private func startStatsig() {
    Statsig.initialize(
      sdkKey: "client-Ffl8pgONvlrjhUh2c4tEUwHQRbVGCplGCpzAwuHLFeE",
      user: StatsigUser(userID: deviceId),
      options: StatsigOptions(),
      completion: { _ in
        // Statsig has finished fetching the latest feature gate and experiment values for your user.
        // If you need the most recent values, you can get them now.

        // You can also check errorMessage for any debugging information.

      })
  }

  /// Shuts down Statsig SDK.
  private func stopStatsig() {
    Statsig.shutdown()
  }

}
