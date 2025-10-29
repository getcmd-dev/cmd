// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

#if DEBUG
#Preview {
  ScrollView {
    VStack(alignment: .leading, spacing: 10) {
      // Running status
      WebFetchToolUseView(toolUse: WebFetchToolUseViewModel(
        status: .Just(.running),
        input: .init(
          url: "https://docs.anthropic.com/en/docs/claude-code",
          prompt: "What are the main features of Claude Code?")))

      // Not started status
      WebFetchToolUseView(toolUse: WebFetchToolUseViewModel(
        status: .Just(.notStarted),
        input: .init(
          url: "https://example.com/api/v1/data",
          prompt: "Extract the API response format")))

      // Completed with result
      WebFetchToolUseView(toolUse: WebFetchToolUseViewModel(
        status: .Just(.completed(.success(.init(
          result: """
            Claude Code is an AI-powered coding assistant with the following main features:

            1. **Interactive CLI** - A command-line interface for conversing with Claude about coding tasks
            2. **File Operations** - Can read, write, edit, and search through files in your codebase
            3. **Web Search & Fetch** - Can search the web and fetch content from URLs
            4. **Task Management** - Built-in todo list for tracking complex multi-step tasks
            5. **Tool Integration** - Extensible tool system for custom functionality
            6. **Memory Management** - CLAUDE.md files for persistent context and instructions
            """)))),
        input: .init(
          url: "https://docs.anthropic.com/en/docs/claude-code",
          prompt: "What are the main features of Claude Code?")))

      // Long URL and prompt
      WebFetchToolUseView(toolUse: WebFetchToolUseViewModel(
        status: .Just(.completed(.success(.init(
          result: "The article discusses various approaches to machine learning optimization...")))),
        input: .init(
          url: "https://example.com/blog/2024/machine-learning/optimization-techniques/gradient-descent-variations?ref=homepage&utm_source=newsletter",
          prompt: "Summarize the key optimization techniques mentioned in this article and explain how they differ from standard gradient descent approaches")))
    }
  }
  .frame(minWidth: 500, minHeight: 500)
  .padding()
}
#endif
