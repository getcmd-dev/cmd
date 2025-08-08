// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AskFollowUpTool
import BuildTool
import ClaudeCodeTools
import EditFilesTool
import ExecuteCommandTool
import LSTool
import ReadFileTool
import SearchFilesTool
import ToolFoundation

extension ToolsPlugin {
  func registerToolsPlugin() {
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
  }
}
