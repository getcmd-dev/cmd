// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

#if DEBUG
#Preview {
  ScrollView {
    VStack(alignment: .leading, spacing: 10) {
      // Running status
      let input1 = ClaudeCodeWebFetchTool.Use.Input(
        url: "https://docs.anthropic.com/en/docs/claude-code",
        prompt: "What are the main features of Claude Code?")
      WebFetchToolUseView(toolUse: WebFetchToolUseViewModel(
        status: .Just(.running(input: input1)),
        input: input1))

      // Not started status
      let input2 = ClaudeCodeWebFetchTool.Use.Input(
        url: "https://example.com/api/v1/data",
        prompt: "Extract the API response format")
      WebFetchToolUseView(toolUse: WebFetchToolUseViewModel(
        status: .Just(.notStarted(input: input2)),
        input: input2))

      // Completed with result
      let input3 = ClaudeCodeWebFetchTool.Use.Input(
        url: "https://docs.anthropic.com/en/docs/claude-code",
        prompt: "What are the main features of Claude Code?")
      WebFetchToolUseView(toolUse: WebFetchToolUseViewModel(
        status: .Just(.completed(input: input3, result: .success(.init(
          result: """
            Claude Code is an AI-powered coding assistant with the following main features:

            1. **Interactive CLI** - A command-line interface for conversing with Claude about coding tasks
            2. **File Operations** - Can read, write, edit, and search through files in your codebase
            3. **Web Search & Fetch** - Can search the web and fetch content from URLs
            4. **Task Management** - Built-in todo list for tracking complex multi-step tasks
            5. **Tool Integration** - Extensible tool system for custom functionality
            6. **Memory Management** - CLAUDE.md files for persistent context and instructions
            """)))),
        input: input3))

      // Long URL and prompt
      let input4 = ClaudeCodeWebFetchTool.Use.Input(
        url: "https://example.com/blog/2024/machine-learning/optimization-techniques/gradient-descent-variations?ref=homepage&utm_source=newsletter",
        prompt: "Summarize the key optimization techniques mentioned in this article and explain how they differ from standard gradient descent approaches")
      WebFetchToolUseView(toolUse: WebFetchToolUseViewModel(
        status: .Just(.completed(input: input4, result: .success(.init(
          result: "The article discusses various approaches to machine learning optimization...")))),
        input: input4))
    }
  }
  .frame(minWidth: 500, minHeight: 500)
  .padding()
}
#endif
