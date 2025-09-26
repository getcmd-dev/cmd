// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import SettingsServiceInterface
import ThreadSafe
import ToolFoundation

#if DEBUG
@ThreadSafe
public final class MockMCPService: MCPService {
  public init() { }

  public var _servers = CurrentValueSubject<[MCPServerConfiguration: MCPServerConnectionStatus], Never>([:])

  public var onLoadSettings: @Sendable () async throws -> MCPSettings = {
    [:]
  }

  public var onSaveSettings: @Sendable (MCPSettings) async throws -> Void = { _ in }

  public var onConnect: @Sendable (MCPServerConfiguration) async throws -> MCPServerConnection = { _ in
    MockMCPServerConnection()
  }

  public var servers: any Publisher<[MCPServerConfiguration: MCPServerConnectionStatus], Never> {
    _servers.eraseToAnyPublisher()
  }

  public func loadSettings() async throws -> MCPSettings {
    try await onLoadSettings()
  }

  public func saveSettings(_ settings: MCPSettings) async throws {
    try await onSaveSettings(settings)
  }

  public func connect(to server: MCPServerConfiguration) async throws -> MCPServerConnection {
    try await onConnect(server)
  }
}

public struct MockMCPServerConnection: MCPServerConnection {
  public init() { }

  public let tools = [any Tool]()
  public let serverInfo = ServerInfo(name: "Mock Server", version: "1.0.0")
  public let configuration = MCPServerConfiguration.stdio(.init(name: "Mock", command: "mock"))

  public func disconnect() async { }
  public func onDisconnection(_: @escaping @Sendable () -> Void) { }
}
#endif
