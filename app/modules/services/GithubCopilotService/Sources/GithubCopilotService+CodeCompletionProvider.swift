// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import CodeCompletionFoundation
import Foundation
import LoggingServiceInterface

extension DefaultGithubCopilotService {
  var id: String {
    "github-copilot"
  }

  func suggestCompletion(
    workspace: URL,
    file: URL,
    content _: String,
    version: Int,
    selection: CodeCompletionFoundation.Range,
    pasteboardContent _: String?)
    async throws -> CompletionSuggestion?
  {
    guard
      let completion = try await lspServer(for: workspace)
        .getCompletions(
          uri: file.absoluteString,
          version: version,
          position: .init(line: selection.start.line, character: selection.start.character),
          tabSize: 2,
          insertSpaces: true).items.first
    else {
      return nil
    }
    if let range = completion.range {
      return CompletionSuggestion(
        file: file,
        startPosition: .init(line: range.start.line, character: range.start.character),
        endPosition: .init(line: range.end.line, character: range.end.character),
        completion: completion.insertText,
        id: UUID())
    } else {
      return CompletionSuggestion(
        file: file,
        startPosition: selection.start,
        endPosition: selection.start, // Start here, as we only give Github the start position of the selected range.
        completion: completion.insertText,
        id: UUID())
    }
  }

  /// Call
  func didOpen(workspace: URL, file: URL, content: String, version: Int) {
    Task(loggingErrorWith: "Failed to send didOpen notification to LSP server") {
      try await self.lspServer(for: workspace).didOpenTextDocument(
        uri: file.absoluteString,
        languageId: "swift",
        // See https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#textDocumentItem
        version: version,
        text: content)
    }
  }

  func didChange(workspace: URL, file: URL, content: String, version: Int) {
    Task(loggingErrorWith: "Failed to send didOpen notification to LSP server") {
      try await self.lspServer(for: workspace).didChangeTextDocument(
        uri: file.absoluteString,
        // See https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#textDocumentItem
        version: version,
        text: content)
    }
  }

  func didSave(workspace: URL, file: URL, content: String, version: Int) {
    Task(loggingErrorWith: "Failed to send didOpen notification to LSP server") {
      try await self.lspServer(for: workspace).didSaveTextDocument(
        uri: file.absoluteString,
        // See https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#textDocumentItem
        version: version,
        text: content)
    }
  }

  func didClose(workspace: URL, file: URL, content _: String, version: Int) {
    Task(loggingErrorWith: "Failed to send didOpen notification to LSP server") {
      try await self.lspServer(for: workspace).didCloseTextDocument(
        uri: file.absoluteString,
        // See https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#textDocumentItem
        version: version)
    }
  }

}
