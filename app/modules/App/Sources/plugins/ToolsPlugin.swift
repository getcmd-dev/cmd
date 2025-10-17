// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

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
  func registerToolsPlugin(mcpService: MCPService) -> AnyCancellable {
    plugIn(tool: LSTool())
    plugIn(tool: ReadFileTool())
    plugIn(tool: SearchFilesTool())
    plugIn(tool: EditFilesTool(shouldAutoApply: true))
    // plugIn(tool: EditFilesTool(shouldAutoApply: false))
    plugIn(tool: ExecuteCommandTool())
    plugIn(tool: AskFollowUpTool())
    plugIn(tool: BuildTool())

    // Claude Code
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

    // MCP tools (server id -> [tool ids])
    let mcpServerConnections = Atomic([String: [String]]())
    // Update MCP tools as they change
    return mcpService.servers.sink { [weak self] servers in
      guard let self else { return }

      let connectedServers = servers.compactMap { status in
        if case .success(let connection) = status {
          return connection
        }
        return nil
      }

      let removedToolIds = mcpServerConnections.mutate { value in
        // Find removed servers
        let connectedServerIds = Set(connectedServers.map(\.configuration.id))
        let removedServerIds = Set(value.keys).subtracting(connectedServerIds)
        var removedTools = removedServerIds.flatMap { serverId -> [String] in
          return value[serverId] ?? []
        }
        // Find tools removed from existing servers
        removedTools += connectedServers.flatMap { server -> [String] in
          let previousToolIds = Set(value[server.configuration.id] ?? [])
          let currentToolIds = Set(server.tools.map(\.id))
          return Array(previousToolIds.subtracting(currentToolIds))
        }
        value = connectedServers.reduce(into: [String: [String]]()) { dict, server in
          dict[server.configuration.name] = server.tools.map(\.id)
        }
        return removedTools
      }

      for toolId in removedToolIds {
        unplug(toolId: toolId)
      }
      for server in connectedServers {
        for tool in server.tools {
          plugIn(tool: tool)
        }
      }
    }
  }
}

// MARK: - UnknownTool.Use + DisplayableToolUse

extension UnknownTool.Use: DisplayableToolUse { }

// MARK: - MCPTool.Use + DisplayableToolUse

extension MCPTool.Use: DisplayableToolUse { }
