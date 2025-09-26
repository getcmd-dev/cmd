// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Testing

import MCP
import MCPServiceInterface
import SettingsServiceInterface
import ShellServiceInterface
import SwiftTesting
import ThreadSafe
import ToolFoundation
@testable import MCPService

// MARK: - DefaultMCPServiceTests

@Suite("DefaultMCPServiceTests")
struct DefaultMCPServiceTests {
  struct Retention {
    @Test
    func test_connectionIsDereferencedWhenServiceIsDeallocated() async throws {
      let weakConnection = WeakBox<MockMCPServerConnection>(nil)
      let didConnect = expectation(description: "did connect")
      let settingsService = MockSettingsService(.init(mcpServers: [
        "test-server": .stdio(.init(name: "test-server", command: "swift test-server")),
      ]))

      var service: DefaultMCPService? = DefaultMCPService(
        settingsService: settingsService,
        shellService: MockShellService(),
        connect: { _, configuration in
          let connection = MockMCPServerConnection(tools: [], configuration: configuration)
          weakConnection.value = connection
          didConnect.fulfill()
          return connection
        })
      try await fulfillment(of: didConnect)
      #expect(weakConnection.value != nil)
      _ = service
      service = nil
      #expect(weakConnection.value == nil)
    }

    @Test
    func test_connectionIsDereferencedWhenRemoved() async throws {
      let weakConnection = WeakBox<MockMCPServerConnection>(nil)
      let didConnect = expectation(description: "did connect")
      let settingsService = MockSettingsService(.init(mcpServers: [
        "test-server": .stdio(.init(name: "test-server", command: "swift test-server")),
      ]))

      let service = DefaultMCPService(
        settingsService: settingsService,
        shellService: MockShellService(),
        connect: { _, configuration in
          let connection = MockMCPServerConnection(tools: [], configuration: configuration)
          weakConnection.value = connection
          didConnect.fulfill()
          return connection
        })
      try await fulfillment(of: didConnect)
      #expect(weakConnection.value != nil)

      let didDeinit = expectation(description: "did deinit connection")
      weakConnection.value?.onDeinit = {
        didDeinit.fulfill()
      }

      settingsService.update(setting: \.mcpServers, to: [:])
      try await fulfillment(of: didDeinit)
      _ = service
    }

    @Test
    func test_connectionIsDereferencedWhenUpdated() async throws {
      let weakConnection = WeakBox<MockMCPServerConnection>(nil)
      let didConnectOnce = expectation(description: "did connect once")
      let settingsService = MockSettingsService(.init(mcpServers: [
        "test-server": .stdio(.init(name: "test-server", command: "swift test-server")),
      ]))

      let connectionCreationCount = Atomic(0)

      let service = DefaultMCPService(
        settingsService: settingsService,
        shellService: MockShellService(),
        connect: { _, configuration in
          let counter = connectionCreationCount.increment()
          let connection = MockMCPServerConnection(tools: [], configuration: configuration)
          if counter == 1 {
            weakConnection.value = connection
            didConnectOnce.fulfill()
          }
          return connection
        })
      try await fulfillment(of: didConnectOnce)
      #expect(weakConnection.value != nil)

      let didDeinit = expectation(description: "did deinit connection")
      weakConnection.value?.onDeinit = {
        didDeinit.fulfill()
      }

      settingsService.update(setting: \.mcpServers, to: [
        "test-server": .stdio(.init(name: "test-server", command: "swift test-server --log-level debug")),
      ])
      try await fulfillment(of: didDeinit)
      _ = service
    }
  }
}

// MARK: - WeakBox

final class WeakBox<T: AnyObject & Sendable>: @unchecked Sendable {
  init(_ value: T?) {
    self.value = value
  }

  weak var value: T?
}

// MARK: - MockMCPServerConnection

@ThreadSafe
final class MockMCPServerConnection: MCPServerConnection {
  init(
    tools: [any ToolFoundation.Tool],
    serverInfo: MCPServiceInterface.ServerInfo = .init(name: "test-server", version: "1.0.0"),
    configuration: SettingsServiceInterface.MCPServerConfiguration)
  {
    self.tools = tools
    self.serverInfo = serverInfo
    self.configuration = configuration
  }

  deinit {
    onDeinit?()
  }

  let tools: [any ToolFoundation.Tool]

  let serverInfo: MCPServiceInterface.ServerInfo

  let configuration: SettingsServiceInterface.MCPServerConfiguration

  var onDisconnect: (@Sendable () -> Void)?

  var onDeinit: (@Sendable () -> Void)?

  func disconnect() async {
    onDisconnect?()
  }

  func onDisconnection(_: @escaping @Sendable () -> Void) { }

}
