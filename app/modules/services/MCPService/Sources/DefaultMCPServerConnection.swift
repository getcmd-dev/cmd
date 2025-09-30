// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import MCP
import MCPServiceInterface
import SettingsServiceInterface
import ThreadSafe
import ToolFoundation

// MARK: - DefaultMCPServerConnection

@ThreadSafe
final class DefaultMCPServerConnection: MCPServerConnection {
  init(transport: Transport, configuration: MCPServerConfiguration) async throws {
    self.configuration = configuration
    self.transport = transport
    let client = Client(name: "cmd", version: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1.0.0")
    self.client = client

    let hasFulfilled = Atomic(false)
    let (promise, continuation) = Future<(ServerInfo, [MCPTool]), Error>.make()

    // Handle cases where the transport disconnects during initialization.
    // One such example is when the stdio transport fails immediately (e.g. command not found).
    // In such case, the transport has already "connnected" (i.e. started the subprocess),
    // but the failure is still immediate, even though not synchronous.
    await (transport as? DisconnectableTransport)?.onDisconnection { error in
      let wasFulfilled = hasFulfilled.set(to: true)
      if !wasFulfilled {
        continuation(.failure(error ?? AppError("Disconnected during initialization")))
      }
    }

    Task {
      do {
        let initializationResults = try await client.connect(transport: transport)
        let serverInfo = ServerInfo(
          name: initializationResults.serverInfo.name,
          version: initializationResults.serverInfo.version)
        let mcpTools = try await client.listAllTools().map { MCPTool(tool: $0, client: client, serverName: serverInfo.name) }

        let wasFulfilled = hasFulfilled.set(to: true)
        if !wasFulfilled {
          continuation(.success((serverInfo, mcpTools)))
        }
      } catch {
        let wasFulfilled = hasFulfilled.set(to: true)
        if !wasFulfilled {
          continuation(.failure(error))
        }
      }
    }

    let (serverInfo, mcpTools) = try await promise.value
    self.serverInfo = serverInfo
    self.mcpTools = mcpTools

    updateConnectionStatusWhenDisconnected()
  }

  deinit {
    let client = self.client
    Task {
      await client.disconnect()
    }
  }

  private(set) var mcpTools: [MCPTool]
  let serverInfo: ServerInfo
  let configuration: MCPServerConfiguration

  var connectionStatus: ReadonlyCurrentValueSubject<MCPServiceInterface.MCPConnectionStatus, Never> {
    mutableConnectionStatus.readonly()
  }

  var tools: [any ToolFoundation.Tool] {
    mcpTools
  }

  func disconnect() async {
    mcpTools.removeAll()
    await client.disconnect()
    mutableConnectionStatus.send(.disconnected(error: nil))
  }

  private let mutableConnectionStatus: CurrentValueSubject<MCPServiceInterface.MCPConnectionStatus, Never> =
    CurrentValueSubject(.connected)

  private let transport: Transport

  private let client: MCP.Client

  private func updateConnectionStatusWhenDisconnected() {
    Task {
      await (transport as? DisconnectableTransport)?.onDisconnection { [weak self] error in
        self?.mutableConnectionStatus.send(.disconnected(error: error))
      }
    }
  }

}

extension MCP.Client {
  func listAllTools() async throws -> [MCP.Tool] {
    var allTools = [MCP.Tool]()
    var cursor: String? = nil
    while true {
      let (tools, nextCursor) = try await listTools(cursor: cursor)
      allTools.append(contentsOf: tools)
      cursor = nextCursor
      if nextCursor == nil {
        break
      }
    }
    return allTools
  }
}

// MARK: - DisconnectableTransport

/// A transport protocol that supports disconnection event handling.
/// Extends the base Transport protocol to provide notifications when the connection is lost.
protocol DisconnectableTransport: Transport {
  /// Registers a callback to be invoked when the transport disconnects.
  /// - Parameter callback: A sendable closure called with an optional error when disconnection occurs.
  ///   If the error is nil, the disconnection was intentional; otherwise, it indicates an unexpected failure.
  func onDisconnection(_: @escaping @Sendable (Error?) -> Void)
}

// TODO: make HTTPTransport conform to DisconnectableTransport.
