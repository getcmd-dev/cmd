// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ACPTool
import AskFollowUpTool
import BuildTool
import ClaudeCodeTools
import Combine
import ConcurrencyFoundation
import DefaultToolView
import EditFilesTool
import ExecuteCommandTool
import LoggingServiceInterface
import LSTool
import MCPService
import MCPServiceInterface
import ReadFileTool
import SearchFilesTool
import ToolFoundation

extension ToolsPlugin {
  /// Registers all available tools with the plugin system and sets up MCP server monitoring.
  /// - Parameter mcpService: The MCP service that manages server connections
  /// - Returns: A cancellable that keeps the MCP server observation active
  func registerToolsPlugin(mcpService: MCPService) -> AnyCancellable {
    // Core file system and execution tools
    plugIn(tool: LSTool())
    plugIn(tool: ReadFileTool())
    plugIn(tool: SearchFilesTool())
    plugIn(tool: EditFilesTool(shouldAutoApply: true))
    // plugIn(tool: EditFilesTool(shouldAutoApply: false))
    plugIn(tool: ExecuteCommandTool())
    plugIn(tool: AskFollowUpTool())
    plugIn(tool: BuildTool())
    plugIn(tool: GlobTool())
    plugIn(tool: PlanTool())
    plugIn(tool: WebFetchTool())
    plugIn(tool: WebSearchTool())

    // ACP (Apple Code Protocol) tools
    ACPTool.allTools.forEach(plugIn(tool:))

    // Claude Code compatibility tools
    plugIn(tool: ClaudeCodeReadTool())
    plugIn(tool: ClaudeCodeLSTool())
    plugIn(tool: ClaudeCodeGlobTool())
    plugIn(tool: ClaudeCodeBashTool())
    plugIn(tool: ClaudeCodeEditTool())
    plugIn(tool: ClaudeCodeMultiEditTool())
    plugIn(tool: ClaudeCodeTodoWriteTool())
    plugIn(tool: ClaudeCodeWriteTool())
    plugIn(tool: ClaudeCodeGrepTool())
    plugIn(tool: ClaudeCodeWebFetchTool())
    plugIn(tool: ClaudeCodeWebSearchTool())

    // Track MCP server connections and their associated tool IDs
    // Maps server ID -> [tool IDs]
    let mcpServerConnections = Atomic([String: [String]]())

    // Monitor MCP servers and dynamically update available tools as servers connect/disconnect
    return mcpService.servers.sink { [weak self] servers in
      guard let self else { return }

      // Extract successfully connected servers from status array
      let connectedServers = servers.compactMap { status in
        if case .success(let connection) = status {
          return connection
        }
        return nil
      }

      // Identify tools that need to be removed (from disconnected servers or updated server configs)
      let removedToolIds = mcpServerConnections.mutate { value in
        // Find servers that are no longer connected
        let connectedServerIds = Set(connectedServers.map(\.configuration.id))
        let removedServerIds = Set(value.keys).subtracting(connectedServerIds)
        var removedTools = removedServerIds.flatMap { serverId -> [String] in
          return value[serverId] ?? []
        }

        // Find tools that were removed from still-connected servers
        removedTools += connectedServers.flatMap { server -> [String] in
          let previousToolIds = Set(value[server.configuration.id] ?? [])
          let currentToolIds = Set(server.tools.map(\.id))
          return Array(previousToolIds.subtracting(currentToolIds))
        }

        // Update the tracking dictionary with current server states
        value = connectedServers.reduce(into: [String: [String]]()) { dict, server in
          dict[server.configuration.name] = server.tools.map(\.id)
        }
        return removedTools
      }

      // Unregister tools that are no longer available
      for toolId in removedToolIds {
        unplug(toolId: toolId)
      }

      // Register all tools from currently connected servers
      for server in connectedServers {
        for tool in server.tools {
          plugIn(tool: tool)
        }
      }
    }
  }
}

// MARK: - UnknownTool.Use + DisplayableToolUse

/// Allows unknown tools to be displayed in the UI
extension UnknownTool.Use: DisplayableToolUse { }

// MARK: - MCPTool.Use + DisplayableToolUse

/// Allows MCP tools to be displayed in the UI
extension MCPTool.Use: DisplayableToolUse { }
