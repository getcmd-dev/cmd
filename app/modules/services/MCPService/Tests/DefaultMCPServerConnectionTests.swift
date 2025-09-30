// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import Foundation
import JSONFoundation
import Logging
import MCP
import SwiftTesting
import Testing
@testable import MCPService

// MARK: - DefaultMCPServerConnectionTests

@Suite("DefaultMCPServerConnectionTests")
struct DefaultMCPServerConnectionTests {
  @Test
  func creatingAConnectionMakesTheExpectedCalls() async throws {
    let didCallConnect = expectation(description: "did call connect")
    let callsCount = Atomic(0)

    let transport = MockTransport(
      connect: { _ in
        didCallConnect.fulfill()
      },
      disconnect: { _ in
      },
      send: { transport, data in
        let count = callsCount.increment()
        let message = try JSONDecoder().decode(BaseMCPJRPCMessage.self, from: data)
        if count == 1 {
          let id = try #require(message.id)
          await transport.write(string: """
            {
              "jsonrpc": "2.0",
              "id": "\(id)",
              "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {
                  "logging": {},
                  "prompts": {
                    "listChanged": true
                  },
                  "resources": {
                    "subscribe": true,
                    "listChanged": true
                  },
                  "tools": {
                    "listChanged": true
                  }
                },
                "serverInfo": {
                  "name": "ExampleServer",
                  "title": "Example Server Display Name",
                  "version": "1.0.0"
                },
                "instructions": "Optional instructions for the client"
              }
            }
            """)
        } else if message.method == "tools/list" {
          let id = try #require(message.id)
          await transport.write(string: """
            {
              "jsonrpc": "2.0",
              "id": "\(id)",
              "result": {
                "tools": [
                  {
                    "name": "get_weather",
                    "title": "Weather Information Provider",
                    "description": "Get current weather information for a location",
                    "inputSchema": {
                      "type": "object",
                      "properties": {
                        "location": {
                          "type": "string",
                          "description": "City name or zip code"
                        }
                      },
                      "required": ["location"]
                    }
                  }
                ]
              }
            }
            """)
        }
      })
    let connection = try await DefaultMCPServerConnection(
      transport: transport,
      configuration: .stdio(.init(name: "test-server", command: "swift test-server")))

    try await fulfillment(of: didCallConnect)
    #expect(connection.mcpTools.map(\.name) == ["mcp__example_server__get_weather"])
  }
}

// MARK: - MockTransport

final actor MockTransport: Transport {
  init(
    connect: @Sendable @escaping (MockTransport) async throws -> Void,
    disconnect: @Sendable @escaping (MockTransport) async -> Void,
    send: @Sendable @escaping (MockTransport, Data) async throws -> Void)
  {
    onConnect = connect
    onDisconnect = disconnect
    onSend = send

    let (stream, continuation) = AsyncThrowingStream<Data, Error>.makeStream()
    self.stream = stream
    streamContinuation = continuation
  }

  let logger = Logging.Logger(label: "mock.transport")

  var onConnect: (MockTransport) async throws -> Void
  var onDisconnect: (MockTransport) async -> Void
  var onSend: (MockTransport, Data) async throws -> Void

  func connect() async throws {
    try await onConnect(self)
  }

  func disconnect() async {
    await onDisconnect(self)
  }

  func send(_ data: Data) async throws {
    try await onSend(self, data)
  }

  func receive() -> AsyncThrowingStream<Data, any Error> {
    stream
  }

  func write(data: Data) {
    streamContinuation.yield(data)
  }

  func write(string: String) {
    streamContinuation.yield(string.utf8Data)
  }

  private let stream: AsyncThrowingStream<Data, Error>
  private let streamContinuation: AsyncThrowingStream<Data, Error>.Continuation

}

// MARK: - BaseMCPJRPCMessage

struct BaseMCPJRPCMessage: Decodable {
  let id: String?
  let method: String?
}
