// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation
import DependencyFoundation
import SettingsServiceInterface
import ToolFoundation

// MARK: - MCPService

/// Type alias for MCP server settings configuration dictionary.
/// Maps server identifiers to their respective configurations.
public typealias MCPSettings = [String: MCPServerConfiguration]

// MARK: - MCPService

/// Service for managing MCP (Model Context Protocol) server settings and configuration.
///
/// This service handles the lifecycle of MCP server connections, including:
/// - Establishing connections to configured servers
/// - Monitoring server connection status
/// - Managing server reconnection and cleanup
public protocol MCPService: Sendable {
  /// A read-only subject that publishes the current status of all MCP server connections.
  ///
  /// The array contains the status of each configured server, which can be:
  /// - `.loading`: Server connection is being established
  /// - `.success`: Server is connected and operational
  /// - `.failure`: Server connection failed with an error
  var servers: ReadonlyCurrentValueSubject<[MCPServerConnectionStatus], Never> { get }

  /// Establishes a connection to the specified MCP server.
  ///
  /// - Parameter server: The server configuration to connect to
  /// - Returns: An active connection to the MCP server
  /// - Throws: Connection errors if the server cannot be reached or configured improperly
  func connect(to server: MCPServerConfiguration) async throws -> MCPServerConnection
}

// MARK: - MCPServerConnectionStatus

public enum MCPServerConnectionStatus: Sendable {
  case loading(_ configuration: MCPServerConfiguration)
  case success(_ connection: MCPServerConnection)
  case failure(_ configuration: MCPServerConfiguration, _ error: Error)
}

// MARK: - MCPServerConnection

public protocol MCPServerConnection: Sendable {
  var tools: [any Tool] { get }
  var serverInfo: ServerInfo { get }
  var configuration: MCPServerConfiguration { get }
  func disconnect() async
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
