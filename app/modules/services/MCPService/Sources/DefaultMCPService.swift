// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import DependencyFoundation
import Foundation
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
    shellService: ShellService,
    connect: @Sendable @escaping (Transport, MCPServerConfiguration) async throws -> MCPServerConnection)
  {
    _connect = connect
    self.settingsService = settingsService
    self.shellService = shellService

    _servers = CurrentValueSubject([:])

    observeSettingsChanges()
  }

  // MARK: - MCPService

  var servers: ReadonlyCurrentValueSubject<[MCPServerConnectionStatus], Never> {
    ReadonlyCurrentValueSubject<[MCPServerConnectionStatus], Never>(
      Array(_servers.value.values),
      publisher: _servers.map {
        Array($0.values)
      }.eraseToAnyPublisher())
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

    return try await _connect(transport, server)
  }

  private let _connect: @Sendable (Transport, MCPServerConfiguration) async throws -> MCPServerConnection

  private let shellService: ShellService

  // MARK: - Private Properties

  private let _servers: CurrentValueSubject<[String: MCPServerConnectionStatus], Never>
  private var settingsObserver: AnyCancellable?
  private var currentSettings = [String: MCPServerConfiguration]()

  private let settingsService: SettingsService

  private var connections = [String: AnyCancellable]()

  private var reloadId: UUID?

  // MARK: - Private Methods

  private func observeSettingsChanges() {
    settingsObserver = settingsService
      .liveValue(for: \.mcpServers)
      .sink { [weak self] newSettings in
        self?.handleSettingsChange(newSettings)
      }
  }

  private func handleSettingsChange(_ newSettings: [String: MCPServerConfiguration]) {
    var removed = [MCPServerConfiguration]()
    var updatedOrAdded = [MCPServerConfiguration]()
    let oldSettings = currentSettings
    // Check for added or modified servers
    for (name, newConfig) in newSettings {
      if let oldConfig = oldSettings[name] {
        if oldConfig.connectionConfigurationDiffers(from: newConfig) {
          updatedOrAdded.append(newConfig)
        }
      } else {
        // New server added
        updatedOrAdded.append(newConfig)
      }
    }

    // Check for removed servers
    for (name, oldConfig) in oldSettings {
      if newSettings[name] == nil {
        removed.append(oldConfig)
      }
    }

    currentSettings = newSettings

    reload(removed: removed, updatedOrAdded: updatedOrAdded)
  }

  private func reload(removed: [MCPServerConfiguration], updatedOrAdded: [MCPServerConfiguration]) {
    inLock { state in
      self.reload(removed: removed, updatedOrAdded: updatedOrAdded, isolating: &state)
    }
  }

  /// This manual isolation is a bit heavy. As some test have shown through their flakiness, it is possible that when `reload` is called twice in a row that the second call finishes first.
  /// Without proper isolation, the first call can update the state after the second call, leading to stale data.
  private func reload(
    removed: [MCPServerConfiguration],
    updatedOrAdded: [MCPServerConfiguration],
    isolating state: inout _InternalState)
  {
    let reloadId = UUID()
    state.reloadId = reloadId

    for serverConfig in removed {
      state.connections.removeValue(forKey: serverConfig.name)
      _servers.value.removeValue(forKey: serverConfig.name)
    }
    for serverConfig in updatedOrAdded {
      _servers.value[serverConfig.name] = .loading(serverConfig)

      let isCancelled = Atomic(false)
      let task = Task {
        try await withTaskCancellationHandler(operation: { [weak self] in
          do {
            if let connection = try await self?.connect(to: serverConfig), !isCancelled.value {
              try Task.checkCancellation()
              let _servers = self?._servers
              self?.inLock { state in
                if state.reloadId == reloadId {
                  _servers?.value[serverConfig.name] = .success(connection)
                }
              }
            }
          } catch {
            if !isCancelled.value {
              try Task.checkCancellation()
              let _servers = self?._servers
              self?.inLock { state in
                if state.reloadId == reloadId {
                  _servers?.value[serverConfig.name] = .failure(serverConfig, error)
                }
              }
            }
          }
        }, onCancel: {
          isCancelled.set(to: true)
        })
      }

      state.connections[serverConfig.name] = AnyCancellable {
        task.cancel()
      }
    }
  }

}

// MARK: - Dependency Registration

extension BaseProviding where
  Self: SettingsServiceProviding,
  Self: ShellServiceProviding
{
  public var mcpService: MCPService {
    shared {
      DefaultMCPService(
        settingsService: settingsService,
        shellService: shellService,
        connect: { transport, configuration in
          try await DefaultMCPServerConnection(transport: transport, configuration: configuration)
        })
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
