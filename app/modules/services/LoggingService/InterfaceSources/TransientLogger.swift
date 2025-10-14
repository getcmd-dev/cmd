// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import FoundationInterfaces
import OSLog
import ThreadSafe

// MARK: - TransientLogger

@ThreadSafe
public final class TransientLogger: Logger {
  init(subsystem: String, category: String) {
    logger = os.Logger(subsystem: subsystem, category: category)
    self.subsystem = subsystem
    self.category = category
  }

  deinit {
    logFile?.closeFile()
  }

  public let subsystem: String
  public let category: String

  public func subLogger(subsystem: String) -> Logger {
    let subsystem = "\(self.subsystem).\(subsystem)"
    return TransientLogger(subsystem: subsystem, category: category)
  }

  public func trace(_ message: String) {
    let formattedMessage = "[Trace] \(message)"
    logger.trace("\(formattedMessage, privacy: .public)")
    writeToFile("\(subsystem).\(category) \(formattedMessage)")
  }

  public func debug(_ message: String) {
    let formattedMessage = "[Debug] \(message)"
    logger.debug("\(formattedMessage, privacy: .public)")
    writeToFile("\(subsystem).\(category) \(formattedMessage)")
  }

  public func info(_ message: String) {
    let formattedMessage = "[Info] \(message)"
    logger.info("\(formattedMessage, privacy: .public)")
    writeToFile("\(subsystem).\(category) \(formattedMessage)")
  }

  public func log(_ message: String) {
    let formattedMessage = "[Log] \(message)"
    logger.log("\(formattedMessage, privacy: .public)")
    writeToFile("\(subsystem).\(category) \(formattedMessage)")
  }

  public func notice(_ message: String) {
    let formattedMessage = "[Notice] \(message)"
    logger.notice("\(formattedMessage, privacy: .public)")
    writeToFile("\(subsystem).\(category) \(formattedMessage)")
  }

  public func error(_ message: String) {
    let formattedMessage = "[Error] \(message)"
    logger.error("\(formattedMessage, privacy: .public)")
    writeToFile("\(subsystem).\(category) \(formattedMessage)")
  }

  public func error(_ error: any Error) {
    self.error(nil, error)
  }

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
  }

  public func record(event: StaticString, value _: String, metadata _: [StaticString: String]? = nil) {
    let formattedMessage = "[Event] \(event)"
    logger.log("\(formattedMessage, privacy: .public)")
    writeToFile("\(subsystem).\(category) \(formattedMessage)")
  }

  /// Current log file URL, created with timestamp for each session
  private var logFile: FileHandle?
  /// Queue for handling concurrent write operations to the log file
  private let fileWriteQueue = TaskQueue<Void, any Error>()

  private let logger: os.Logger

  /// Writes a message to the log file
  private func writeToFile(_ message: String) {
    let formattedMessage = "\(Date().ISO8601Format()) \(message)\n"
    guard let logFile, let data = formattedMessage.data(using: .utf8) else { return }
    fileWriteQueue.queue {
      logFile.write(data)
    }
  }

}
