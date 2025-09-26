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
      // given
      let weakConnection = WeakBox<MockMCPServerConnection>(nil)
      let didConnect = expectation(description: "did connect")
      let settingsService = MockSettingsService(.init(mcpServers: [
        "test-server": .stdio(.init(name: "test-server", command: "swift test-server")),
      ]))

      var sut: DefaultMCPService? = DefaultMCPService(
        settingsService: settingsService,
        shellService: MockShellService(),
        connect: { _, configuration in
          let connection = MockMCPServerConnection(tools: [], configuration: configuration)
          weakConnection.value = connection
          didConnect.fulfill()
          return connection
        })

      // when
      try await fulfillment(of: didConnect)
      #expect(weakConnection.value != nil)
      _ = sut
      sut = nil

      // then
      #expect(weakConnection.value == nil)
    }

    @Test
    func test_connectionIsDereferencedWhenRemoved() async throws {
      // given
      let weakConnection = WeakBox<MockMCPServerConnection>(nil)
      let didConnect = expectation(description: "did connect")
      let settingsService = MockSettingsService(.init(mcpServers: [
        "test-server": .stdio(.init(name: "test-server", command: "swift test-server")),
      ]))

      let sut = DefaultMCPService(
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

      // when
      settingsService.update(setting: \.mcpServers, to: [:])

      // then
      try await fulfillment(of: didDeinit)
      _ = sut
    }

    @Test
    func test_connectionIsDereferencedWhenUpdated() async throws {
      // given
      let weakConnection = WeakBox<MockMCPServerConnection>(nil)
      let didConnectOnce = expectation(description: "did connect once")
      let settingsService = MockSettingsService(.init(mcpServers: [
        "test-server": .stdio(.init(name: "test-server", command: "swift test-server")),
      ]))

      let connectionCreationCount = Atomic(0)

      let sut = DefaultMCPService(
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

      // when
      settingsService.update(setting: \.mcpServers, to: [
        "test-server": .stdio(.init(name: "test-server", command: "swift test-server --log-level debug")),
      ])

      // then
      try await fulfillment(of: didDeinit)
      _ = sut
    }
  }

  @Test
  func test_loadServerDefinedInSettings() async throws {
    // given
    let didConnectToStdioServer = expectation(description: "did connect to stdio server")
    let didConnectToHttpServer = expectation(description: "did connect to http server")
    let settingsService = MockSettingsService(.init(mcpServers: [
      "test-stdio-server": .stdio(.init(name: "test-stdio-server", command: "swift test-server")),
      "test-http-server": .http(.init(name: "test-http-server", url: "http://localhost:8080")),
    ]))

    // when
    let sut = DefaultMCPService(
      settingsService: settingsService,
      shellService: MockShellService(),
      connect: { _, configuration in
        switch configuration {
        case .http:
          didConnectToHttpServer.fulfill()
        case .stdio:
          didConnectToStdioServer.fulfill()
        }
        return MockMCPServerConnection(tools: [], configuration: configuration)
      })

    // then
    try await fulfillment(of: [didConnectToHttpServer, didConnectToStdioServer])
    #expect(sut.servers.currentValue.count == 2)
  }

  @Test
  func test_reloadServerWhenSettingsChange() async throws {
    // given
    let didConnectToStdioServer = expectation(description: "did connect to stdio server")
    let didConnectToHttpServer = expectation(description: "did connect to http server")
    let settingsService = MockSettingsService(.init(mcpServers: [
      "test-stdio-server": .stdio(.init(name: "test-stdio-server", command: "swift test-server")),
    ]))

    let sut = DefaultMCPService(
      settingsService: settingsService,
      shellService: MockShellService(),
      connect: { _, configuration in
        switch configuration {
        case .http:
          didConnectToHttpServer.fulfill()
        case .stdio:
          didConnectToStdioServer.fulfill()
        }
        return MockMCPServerConnection(tools: [], configuration: configuration)
      })

    try await fulfillment(of: didConnectToStdioServer)
    #expect(sut.servers.currentValue.count == 1)

    // when
    settingsService.update(setting: \.mcpServers, to: [
      "test-stdio-server": .stdio(.init(name: "test-stdio-server", command: "swift test-server")),
      "test-http-server": .http(.init(name: "test-http-server", url: "http://localhost:8080")),
    ])

    // then
    try await fulfillment(of: didConnectToHttpServer)
    #expect(sut.servers.currentValue.count == 2)
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
