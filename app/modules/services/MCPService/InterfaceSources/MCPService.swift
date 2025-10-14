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

/// Represents the current status of an MCP server connection.
///
/// This enum tracks the lifecycle state of each MCP server connection,
/// from initial loading through successful connection or failure.
public enum MCPServerConnectionStatus: Sendable {
  /// The server connection is currently being established.
  ///
  /// - Parameter configuration: The server configuration being connected to
  case loading(_ configuration: MCPServerConfiguration)

  /// The server connection has been successfully established.
  ///
  /// - Parameter connection: The active server connection
  case success(_ connection: MCPServerConnection)

  /// The server connection failed to establish.
  ///
  /// - Parameters:
  ///   - configuration: The server configuration that failed to connect
  ///   - error: The error that caused the connection failure
  case failure(_ configuration: MCPServerConfiguration, _ error: Error)
}

// MARK: - MCPConnectionStatus

/// The status of a connection that was previously established.
public enum MCPConnectionStatus: Sendable {
  /// The server connection is active and operational.
  case connected

  /// The server connection has been terminated.
  ///
  /// - Parameter error: The error that caused disconnection, if any. `nil` indicates a clean disconnection.
  case disconnected(error: Error?)
}

// MARK: - MCPServerConnection

/// Represents an active connection to an MCP server.
///
/// This protocol defines the interface for interacting with a connected MCP server,
/// providing access to server tools, metadata, and connection management.
public protocol MCPServerConnection: Sendable {
  /// The collection of tools provided by the connected MCP server.
  ///
  /// These tools can be invoked to perform various operations supported by the server.
  var tools: [any Tool] { get }

  /// Information about the connected server implementation.
  ///
  /// Contains metadata such as server name and version.
  var serverInfo: ServerInfo { get }

  /// The configuration used to establish this connection.
  ///
  /// Provides access to the original server configuration parameters.
  var configuration: MCPServerConfiguration { get }

  /// Disconnects from the MCP server.
  ///
  /// This method cleanly closes the connection and releases associated resources.
  /// After calling this method, the connection should not be used for further operations.
  func disconnect() /// A subject that publishes the current connection status.
    ///
    /// Emits `.connected` when the server is operational and `.disconnected` when the connection is lost.
    async

  var connectionStatus: ReadonlyCurrentValueSubject<MCPConnectionStatus, Never> { get }
}

// MARK: - ServerInfo

/// Contains metadata about an MCP server implementation.
///
/// This structure provides identification and version information
/// for connected MCP servers.
public struct ServerInfo: Hashable, Codable, Sendable {
  /// The name of the MCP server implementation.
  ///
  /// This is a human-readable identifier for the server.
  public let name: String

  /// The version of the MCP server implementation.
  ///
  /// Version string following semantic versioning conventions.
  public let version: String

  /// Creates a new ServerInfo instance.
  ///
  /// - Parameters:
  ///   - name: The server implementation name
  ///   - version: The server implementation version
  public init(name: String, version: String) {
    self.name = name
    self.version = version
  }
}

// MARK: - MCPServiceProviding

/// Protocol for types that provide access to an MCPService instance.
///
/// This protocol is typically implemented by dependency injection containers
/// or service locators to provide access to MCP functionality.
public protocol MCPServiceProviding {
  /// The MCP service instance for managing server connections.
  var mcpService: MCPService { get }
}
