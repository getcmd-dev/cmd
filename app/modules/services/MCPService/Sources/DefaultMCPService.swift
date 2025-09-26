// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import DependencyFoundation
import Foundation
import FoundationInterfaces
import JSONFoundation
import LoggingServiceInterface
import MCP
import MCPServiceInterface
import SettingsServiceInterface
import ShellServiceInterface
import ThreadSafe
import ToolFoundation

// MARK: - DefaultMCPService

@ThreadSafe
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

    _servers = CurrentValueSubject([:])

    observeSettingsChanges()
  }

  // MARK: - MCPService

  var servers: any Publisher<[MCPServerConfiguration: Result<MCPServerConnection, Error>], Never> {
    _servers.eraseToAnyPublisher()
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

  // MARK: - Private Properties

  private let _servers: CurrentValueSubject<[MCPServerConfiguration: Result<MCPServerConnection, Error>], Never>
  private let reloadTaskQueue = ReplaceableTaskQueue<Void>()
  private var settingsObserver: AnyCancellable?
  private var currentSettings = [String: MCPServerConfiguration]()

  private let settingsService: SettingsService
  private let fileManager: FileManagerI

  // MARK: - Private Methods

  private func observeSettingsChanges() {
    settingsObserver = settingsService
      .liveValue(for: \.mcpServers)
      .sink { [weak self] newSettings in
        self?.handleSettingsChange(newSettings)
      }
  }

  private func handleSettingsChange(_ newSettings: [String: MCPServerConfiguration]) {
    let changedServers = getChangedServers(from: currentSettings, to: newSettings)
    currentSettings = newSettings

    if !changedServers.isEmpty {
      reloadTaskQueue.queue { [weak self] in
        await self?.reloadServers(changedServers)
      }
    }
  }

  private func getChangedServers(
    from oldSettings: [String: MCPServerConfiguration],
    to newSettings: [String: MCPServerConfiguration])
    -> Set<MCPServerConfiguration>
  {
    var changedServers = Set<MCPServerConfiguration>()

    // Check for added or modified servers
    for (name, newConfig) in newSettings {
      if let oldConfig = oldSettings[name] {
        if oldConfig.connectionConfigurationDiffers(from: newConfig) {
          changedServers.insert(newConfig)
        }
      } else {
        // New server added
        changedServers.insert(newConfig)
      }
    }

    // Check for removed servers
    for (name, oldConfig) in oldSettings {
      if newSettings[name] == nil {
        changedServers.insert(oldConfig)
      }
    }

    return changedServers
  }

  private func reloadServers(_ changedServers: Set<MCPServerConfiguration>) async {
    var updatedServers = _servers.value

    // Remove old connections for changed servers
    for server in changedServers {
      let removed = updatedServers.removeValue(forKey: server)
      Task {
        try? await removed?.get().disconnet()
      }
    }

    // Only reload servers that are enabled and still in current settings
    let serversToReload = changedServers.filter { server in
      !server.disabled && currentSettings.values.contains(server)
    }

    // Connect to new/updated servers
    await withTaskGroup(of: (MCPServerConfiguration, Result<MCPServerConnection, Error>).self) { group in
      for server in serversToReload {
        group.addTask {
          let result = await Result {
            try await self.connect(to: server)
          }
          return (server, result)
        }
      }

      for await (server, result) in group {
        updatedServers[server] = result
      }
    }

    _servers.send(updatedServers)
  }

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

extension MCPServerConfiguration {
  func connectionConfigurationDiffers(from other: MCPServerConfiguration) -> Bool {
    switch (self, other) {
    case (.stdio(let config1), .stdio(let config2)):
      config1.command != config2.command ||
        config1.args != config2.args ||
        config1.env != config2.env

    case (.http(let config1), .http(let config2)):
      config1.url != config2.url ||
        config1.headers != config2.headers

    default:
      true
    }
  }
}
