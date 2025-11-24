// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import CodeCompletionFoundation
import CodeCompletionServiceInterface
import DependencyFoundation
import Foundation
import LLMFoundation
import LocalServerServiceInterface
import SettingsServiceInterface
import SharedValuesFoundation
import ThreadSafe

// MARK: - APIBasedCodeCompletionProvider

@ThreadSafe
final class APIBasedCodeCompletionProvider: CodeCompletionProvider {
  init(
    id: String,
    displayName: String,
    model: String,
    providerName: Schema.APIProviderName,
    localServer: LocalServer,
    settingsService: SettingsService)
  {
    self.id = id
    self.displayName = displayName
    self.model = model
    self.providerName = providerName
    self.localServer = localServer
    self.settingsService = settingsService
  }

  let id: String
  let displayName: String

  var recentEditsTrackers: (@Sendable (URL) async -> RecentEditsTracker?) = { _ in nil }

  var isAvailable: Bool {
    provider != nil
  }

  var provider: Schema.APIProvider? {
    guard
      let provider = AIProvider(rawValue: providerName.rawValue),
      let settings = settingsService.value(for: \.llmProviderSettings).first(where: { $0.key == provider })?.value
    else {
      return nil
    }
    return .init(
      name: providerName,
      settings: .init(
        apiKey: settings.apiKey,
        baseUrl: settings.baseUrl,
        localExecutable: nil))
  }

  /// Split content into prefix and suffix at the given position
  /// - Parameters:
  ///   - content: The file content
  ///   - position: The cursor position
  /// - Returns: A tuple of (prefix, suffix)
  /// - Throws: AppError if the position is invalid
  static func splitContent(_ content: String, at position: Position) throws -> (prefix: String, suffix: String) {
    let lines = content.splitLines()
    let lineOffsets = lines.reduce(into: [Int](), { acc, l in
      acc.append((acc.last ?? 0) + l.count)
    })

    if position.line > lineOffsets.count {
      throw AppError("Selection line \(position.line) exceeds content lines \(lineOffsets.count)")
    }

    let lineOffset = position.line == 0 ? 0 : lineOffsets[position.line - 1]
    let offset = lineOffset + position.character

    guard offset <= content.count else {
      throw AppError("Invalid offset: \(offset) exceeds content length: \(content.count)")
    }

    let prefix = String(content.prefix(upTo: content.index(content.startIndex, offsetBy: offset)))
    let suffix = String(content.suffix(from: content.index(content.startIndex, offsetBy: offset)))

    return (prefix, suffix)
  }

  func suggestCompletion(
    workspace: any Workspace,
    file: URL,
    content: String,
    version _: Int,
    selection: Range,
    pasteboardContent: String?,
    formattingMetadata: FileFormattingMetadata?)
    async throws -> RawCompletionSuggestion?
  {
    guard let provider else {
      throw AppError("The provider \(providerName.rawValue) is not configured for autocompletion")
    }

    // Split content into prefix and suffix based on selection
    let (prefix, suffix) = try Self.splitContent(content, at: selection.start)

    // Convert formatting metadata to schema type
    let formattingMetadata = formattingMetadata ?? FileFormattingMetadata(
      tabSize: 4,
      indentSize: 4,
      usesTabsForIndentation: false,
      uti: "")

    let schemaFormattingMetadata = Schema.FileFormattingMetadata(
      tabSize: formattingMetadata.tabSize,
      indentSize: formattingMetadata.indentSize,
      usesTabsForIndentation: formattingMetadata.usesTabsForIndentation,
      uti: formattingMetadata.uti ?? "")

    // Convert selection to schema type
    let schemaSelection = Schema.CursorRange(
      start: Schema.CursorPosition(
        line: selection.start.line,
        character: selection.start.character),
      end: Schema.CursorPosition(
        line: selection.end.line,
        character: selection.end.character))

    let requestParams = await Schema.CodeCompletionRequestParams(
      model: model,
      provider: provider,
      selection: schemaSelection,
      recentEdits: recentEditsTrackers(workspace.url)?.diff,
      pasteboardContent: pasteboardContent,
      formattingMetadata: schemaFormattingMetadata,
      prefix: prefix,
      suffix: suffix,
      filepath: file.path)

    let requestData = try JSONEncoder().encode(requestParams)

    let response: Schema.CodeCompletionResponseParams = try await localServer.postRequest(
      path: "completeCode",
      data: requestData)

    // Return first choice if available
    guard let firstChoice = response.choices.first else {
      return nil
    }

    // For now, return the completion text as-is
    // In a full implementation, we would calculate proper start/end positions
    return RawCompletionSuggestion(
      file: file,
      startPosition: .init(line: firstChoice.changedRange.start.line, character: firstChoice.changedRange.start.character),
      endPosition: .init(line: firstChoice.changedRange.end.line, character: firstChoice.changedRange.end.character),
      completion: firstChoice.text,
      id: UUID())
  }

  func setUp(workspace _: any Workspace) {
    // No-op for API-based provider
  }

  func close(workspace _: URL) {
    // No-op for API-based provider
  }

  func didOpen(workspace _: any Workspace, file _: URL, content _: String, version _: Int) {
    // No-op for API-based provider
  }

  func didChange(workspace _: any Workspace, file _: URL, content _: String, version _: Int) {
    // No-op for API-based provider
  }

  func didSave(workspace _: any Workspace, file _: URL, content _: String, version _: Int) {
    // No-op for API-based provider
  }

  func didClose(workspace _: any Workspace, file _: URL, content _: String, version _: Int) {
    // No-op for API-based provider
  }

  func didDelete(workspace _: any Workspace, file _: URL) {
    // No-op for API-based provider
  }

  private let model: String
  private let providerName: Schema.APIProviderName
  private let localServer: LocalServer
  private let settingsService: SettingsService

}

extension BaseProviding where
  Self: LocalServerProviding,
  Self: SettingsServiceProviding,
  Self: CodeCompletionServiceProviding
{
  public var mistralCodeCompletionProvider: CodeCompletionProvider {
    APIBasedCodeCompletionProvider(
      id: "mistral",
      displayName: "Mistral",
      model: "codestral-latest",
      providerName: .mistral,
      localServer: localServer,
      settingsService: settingsService)
  }

  public var inceptionCodeCompletionProvider: CodeCompletionProvider {
    APIBasedCodeCompletionProvider(
      id: "inception",
      displayName: "Inception",
      model: "mercury-coder",
      providerName: .inception,
      localServer: localServer,
      settingsService: settingsService)
  }
}
