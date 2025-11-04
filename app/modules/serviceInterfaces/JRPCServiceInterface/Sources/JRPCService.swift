// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import LoggingServiceInterface

// MARK: - JRPCService

public protocol JRPCService: Sendable {
  func createConnection(command: String, env: [String: String], pwd: String?, configuration: STDIOConfiguration)
    -> StdioConnection
}

// MARK: - StdioConnection

public protocol StdioConnection: Sendable {
  // var logger: Logger { get }

  /// Establishes connection with the transport
  func connect() async throws

  /// Disconnects from the transport
  func disconnect() /// Sends data
    async

  func send(_ data: Data) async throws

  /// Receives data in an async sequence
  func receive() -> AsyncThrowingStream<Data, Swift.Error>

  func onDisconnection(_ disconnectionHandler: @escaping @Sendable (Error?) -> Void) async
}

// MARK: - STDIODelimitation

/// How each message is delimited when sent to the transport
public enum STDIODelimitation: Sendable {
  /// A new line is added to the end of the message
  case newLine
  /// A content length header is added to the message
  case contentLength
  /// No delimitation is added to the message
  case none
}

// MARK: - STDIOConfiguration

public struct STDIOConfiguration: Sendable {
  public let delimitation: STDIODelimitation
  public let logger: LoggingServiceInterface.Logger?
  public init(delimitation: STDIODelimitation, logger: LoggingServiceInterface.Logger? = nil) {
    self.delimitation = delimitation
    self.logger = logger
  }
}

// MARK: - JRPCServiceProviding

public protocol JRPCServiceProviding {
  var jrpcService: any JRPCService { get }
}
