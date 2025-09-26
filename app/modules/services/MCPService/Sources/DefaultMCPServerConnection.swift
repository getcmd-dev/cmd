// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

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
    let client = Client(name: "cmd", version: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1.0.0")
    self.client = client
    let initializationResults = try await client.connect(transport: transport)
    serverInfo = .init(name: initializationResults.serverInfo.name, version: initializationResults.serverInfo.version)
    mcpTools = try await client.listAllTools().map { MCPTool(tool: $0, client: client) }
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

  var tools: [any ToolFoundation.Tool] {
    mcpTools
  }

  func disconnect() async {
    // TODO: add test to ensure the client is dereferrenced and disconnected.
    mcpTools.removeAll()
    let client = client
    Task {
      await client.disconnect()
    }
  }

  func onDisconnection(_: @escaping @Sendable () -> Void) { }

  private let client: MCP.Client

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
