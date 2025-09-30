// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - Logger

/// A protocol for logging messages at different levels with optional file logging support.
/// Provides methods for debug, info, log, notice, and error logging.
public protocol Logger: Sendable {

  /// Creates a sub-logger with an extended subsystem name.
  func subLogger(subsystem: String) -> Logger

  /// Logs a trace message.
  func trace(_ message: String)
  /// Logs a debug message.
  func debug(_ message: String)
  /// Logs an informational message.
  func info(_ message: String)
  /// Logs a general message.
  func log(_ message: String)
  /// Logs a notice message.
  func notice(_ message: String)
  /// Logs an error message.
  func error(_ message: String)
  /// Logs an error object.
  func error(_ error: any Error)
  /// Logs an error with an optional descriptive message.
  func error(_ message: String?, _ error: any Error)
  /// Records an event with value and optional metadata.
  func record(event: StaticString, value: String, metadata: [StaticString: String]?)

  var subsystem: String { get }
  var category: String { get }
}

extension Logger {
  public func record(event: StaticString, metadata: [StaticString: String]? = nil) {
    record(event: event, value: "NA", metadata: metadata)
  }

  public func record(event: StaticString, value: String) {
    record(event: event, value: value, metadata: nil)
  }
}

/// The global default logger.
/// For convenience, this is globally accessible instead of passed through the dependency injection system.
/// Changing this value is not thread safe and should be done cautiously.
nonisolated(unsafe) public var defaultLogger: Logger = TransientLogger(
  subsystem: Bundle.main.bundleIdentifier ?? "UnknownApp",
  category: "command")

// MARK: - StaticString + @retroactive Hashable

extension StaticString: @retroactive Hashable {
  public var string: String {
    "\(self)"
  }

  public static func ==(lhs: StaticString, rhs: StaticString) -> Bool {
    lhs.string == rhs.string
  }

  public func hash(into hasher: inout Hasher) {
    string.hash(into: &hasher)
  }

}
