// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import DependencyFoundation
import SettingsServiceInterface
import ToolFoundation

// MARK: - MCPService

public typealias MCPSettings = [String: MCPServerConfiguration]

// MARK: - MCPService

/// Service for managing MCP (Model Context Protocol) server settings and configuration.
public protocol MCPService: Sendable {
  var servers: Publisher<[MCPServerConfiguration: Result<MCPServerConnection, Error>], Never> { get }

  func connect(to server: MCPServerConfiguration) async throws -> MCPServerConnection
}

// MARK: - MCPServerConnection

public protocol MCPServerConnection: Sendable {
  var tools: [any Tool] { get }
  var serverInfo: ServerInfo { get }
  var configuration: MCPServerConfiguration { get }
  func disconnet() async
  func onDisconnection(_ handler: @escaping @Sendable () -> Void)
}

// MARK: - ServerInfo

/// Implementation information
public struct ServerInfo: Hashable, Codable, Sendable {
  /// The server name
  public let name: String
  /// The server version
  public let version: String

  public init(name: String, version: String) {
    self.name = name
    self.version = version
  }
}

// MARK: - MCPServiceProviding

public protocol MCPServiceProviding {
  var mcpService: MCPService { get }
}
