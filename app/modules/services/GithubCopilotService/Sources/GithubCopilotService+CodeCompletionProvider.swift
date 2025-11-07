// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import CodeCompletionFoundation
import Foundation
import LoggingServiceInterface
import SharedValuesFoundation

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
    pasteboardContent _: String?,
    formattingMetadata: FileFormattingMetadata?)
    async throws -> CompletionSuggestion?
  {
    // Use formatting metadata from Xcode if available, otherwise use defaults
    let tabSize = formattingMetadata?.tabSize ?? 2
    let insertSpaces = formattingMetadata.map { !$0.usesTabsForIndentation } ?? true

    guard
      let completion = try await lspServer(for: workspace)?
        .getCompletions(
          uri: file.absoluteString,
          version: version,
          position: .init(line: selection.start.line, character: selection.start.character),
          tabSize: tabSize,
          insertSpaces: insertSpaces).items.first
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

  func didOpen(workspace: URL, file: URL, content: String, version: Int) {
    Task(loggingErrorWith: "Failed to send didOpen notification to LSP server") {
      // Determine language ID from file extension
      let languageId = LanguageIdentifier.languageId(from: file)

      try await self.lspServer(for: workspace)?.didOpenTextDocument(
        uri: file.absoluteString,
        languageId: languageId,
        // See https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#textDocumentItem
        version: version,
        text: content)
    }
  }

  func didChange(workspace: URL, file: URL, content: String, version: Int) {
    Task(loggingErrorWith: "Failed to send didChange notification to LSP server") {
      try await self.lspServer(for: workspace)?.didChangeTextDocument(
        uri: file.absoluteString,
        // See https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#textDocumentItem
        version: version,
        text: content)
    }
  }

  func didSave(workspace: URL, file: URL, content: String, version: Int) {
    Task(loggingErrorWith: "Failed to send didSave notification to LSP server") {
      try await self.lspServer(for: workspace)?.didSaveTextDocument(
        uri: file.absoluteString,
        // See https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#textDocumentItem
        version: version,
        text: content)
    }
  }

  func didClose(workspace: URL, file: URL, content _: String, version: Int) {
    Task(loggingErrorWith: "Failed to send didClose notification to LSP server") {
      try await self.lspServer(for: workspace)?.didCloseTextDocument(
        uri: file.absoluteString,
        // See https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#textDocumentItem
        version: version)
    }
  }

  func didDelete(workspace _: URL, file _: URL) {
    // Empty implementation - LSP server doesn't have a didDelete notification
  }

}
