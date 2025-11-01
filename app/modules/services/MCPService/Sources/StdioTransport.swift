// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

// TODO: use the ShellService directly once https://github.com/swiftlang/swift-subprocess/issues/186 is fixed

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import JRPCServiceInterface
import Logging
import LoggingServiceInterface
import MCP
import ShellServiceInterface

// MARK: - StdioTransport

actor StdioTransport: DisconnectableTransport {
  init(connection: StdioConnection) {
    self.connection = connection
  }

  var logger: Logging.Logger { .init(label: "cmd.mcp") }

  func onDisconnection(_ disconnectionHandler: @escaping @Sendable ((any Error)?) -> Void) async {
    await connection.onDisconnection(disconnectionHandler)
  }

  func disconnect() async {
    await connection.disconnect()
  }

  func send(_ data: Data) async throws {
    try await connection.send(data)
  }

  func receive() -> AsyncThrowingStream<Data, any Error> {
    connection.receive()
  }

  func connect() async throws {
    try await connection.connect()
  }

  private let connection: StdioConnection

}
