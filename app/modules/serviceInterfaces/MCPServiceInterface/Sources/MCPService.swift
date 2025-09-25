// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DependencyFoundation
import SettingsServiceInterface
import ToolFoundation

// MARK: - MCPService

public typealias MCPSettings = [String: MCPServerConfiguration]

// MARK: - MCPService

/// Service for managing MCP (Model Context Protocol) server settings and configuration.
public protocol MCPService: Sendable {
//  /// Load MCP settings from persistent storage.
//  func loadSettings() async throws -> MCPSettings
//
//  /// Save MCP settings to persistent storage.
//  func saveSettings(_ settings: MCPSettings) async throws

  func connect(to server: MCPServerConfiguration) async throws -> MCPServerConnection
}

// MARK: - MCPServerConnection

public protocol MCPServerConnection: Sendable {
  var tools: [any Tool] { get }
  var serverInfo: ServerInfo { get }
  var configuration: MCPServerConfiguration { get }
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

//
// public enum MCPServerConfiguration: Codable, Sendable {
//    case stdio(_ configuration: MCPServerStdioConfiguration)
//    case http(_ configuration: MCPServerHttpConfiguration)
//
//    public var name: String {
//        switch self {
//        case .stdio(let config):
//            return config.name
//        case .http(let config):
//            return config.name
//        }
//    }
//
//    public var disabled: Bool {
//        switch self {
//        case .stdio(let config):
//            return config.disabled
//        case .http(let config):
//            return config.disabled
//        }
//    }
//
//    public var autoApprove: [String]? {
//        switch self {
//        case .stdio(let config):
//            return config.autoApprove
//        case .http(let config):
//            return config.autoApprove
//        }
//    }
//
//    public struct MCPServerStdioConfiguration: Codable, Sendable {
//        public let name: String
//        public let command: String
//        public let args: [String]?
//        public let env: [String: String]?
//        public let disabled: Bool
//        public let autoApprove: [String]?
//
//        public init(name: String, command: String, args: [String]? = nil, env: [String: String]? = nil, disabled: Bool = false, autoApprove: [String]? = nil) {
//            self.name = name
//            self.command = command
//            self.args = args
//            self.env = env
//            self.disabled = disabled
//            self.autoApprove = autoApprove
//        }
//    }
//
//    public struct MCPServerHttpConfiguration: Codable, Sendable {
//        public let name: String
//        public let url: String
//        public let headers: [String: String]?
//        public let disabled: Bool
//        public let autoApprove: [String]?
//
//        public init(name: String, url: String, headers: [String: String]? = nil, disabled: Bool = false, autoApprove: [String]? = nil) {
//            self.name = name
//            self.url = url
//            self.headers = headers
//            self.disabled = disabled
//            self.autoApprove = autoApprove
//        }
//    }
// }
