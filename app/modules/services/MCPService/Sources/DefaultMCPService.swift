// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import DependencyFoundation
import Foundation
import FoundationInterfaces
import JSONFoundation
import LoggingServiceInterface
import MCP
import MCPServiceInterface
import SettingsServiceInterface
import ShellServiceInterface
import ToolFoundation

// MARK: - DefaultMCPService

final class DefaultMCPService: MCPService {

  // MARK: - Initialization

  init(
    settingsService: SettingsService,
    fileManager: FileManagerI,
    shellService: ShellService)
  {
    self.settingsService = settingsService
    self.fileManager = fileManager
    self.shellService = shellService
  }

  func connect(to server: MCPServerConfiguration) async throws -> MCPServerConnection {
    let transport: Transport = try {
      switch server {
      case .stdio(let config):
        return shellService.transport(command: config.command + (config.args?.map { " " + $0 }.joined() ?? ""))
      case .http(let config):
        guard let endpoint = URL(string: config.url) else {
          throw AppError("Invalid URL: \(config.url)")
        }
        return HTTPClientTransport(
          endpoint: endpoint,
          requestModifier: { request in
            var modifiedRequest = request
            config.headers?.forEach({ key, value in
              modifiedRequest.addValue(value, forHTTPHeaderField: key)
            })
            return modifiedRequest
          })
      }
    }()

    return try await DefaultMCPServerConnection(transport: transport, configuration: server)
  }

  private let shellService: ShellService

  // MARK: - MCPService

//  func loadSettings() async throws -> MCPSettings {
//    let settingsURL = try mcpSettingsURL()
//
//    guard fileManager.fileExists(atPath: settingsURL.path) else {
//      // Return default settings if file doesn't exist
//      return MCPSettings(enabledServers: [:])
//    }
//
//    let data = try Data(contentsOf: settingsURL)
//    return try JSONDecoder().decode(MCPSettings.self, from: data)
//  }
//
//  func saveSettings(_ settings: MCPSettings) async throws {
//    let settingsURL = try mcpSettingsURL()
//
//    // Create directory if it doesn't exist
//    let settingsDirectory = settingsURL.deletingLastPathComponent()
//    try fileManager.createDirectory(
//      at: settingsDirectory,
//      withIntermediateDirectories: true,
//      attributes: nil
//    )
//
//    let data = try JSONEncoder.sortingKeys.encode(settings)
//    try data.write(to: settingsURL)
//  }

  private let settingsService: SettingsService
  private let fileManager: FileManagerI

}

// MARK: - Dependency Registration

extension BaseProviding where
  Self: SettingsServiceProviding,
  Self: FileManagerProviding,
  Self: ShellServiceProviding
{
  public var mcpService: MCPService {
    shared {
      DefaultMCPService(
        settingsService: settingsService,
        fileManager: fileManager,
        shellService: shellService)
    }
  }
}

extension ShellService {
  func transport(command: String) -> Transport {
    StdioTransport(command: command, shellService: self)
  }
}
