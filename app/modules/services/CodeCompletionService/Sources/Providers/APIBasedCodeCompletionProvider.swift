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

  func suggestCompletion(
    workspace _: any Workspace,
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
    let lines = content.splitLines()
    let lineOffsets = lines.reduce(into: [Int](), { acc, l in
      acc.append((acc.last ?? 0) + l.count)
    })
    if selection.start.line > lineOffsets.count {
      throw AppError("Corrupted content")
    }
    let lineOffset = selection.start.line == 0 ? 0 : lineOffsets[selection.start.line - 1]
    let offset = lineOffset + selection.start.character

    guard offset <= content.count else {
      throw AppError("Invalid offset: \(offset) exceeds content length: \(content.count)")
    }
    let prefix = String(content.prefix(upTo: content.index(content.startIndex, offsetBy: offset)))
    let suffix = String(content.suffix(from: content.index(content.startIndex, offsetBy: offset)))
    print(selection.start.line, selection.start.character, offset, prefix.splitLines().last, suffix.splitLines().first)

    // Convert formatting metadata to schema type
    guard let formattingMetadata else {
      return nil
    }

    let schemaFormattingMetadata = Schema.FileFormattingMetadata(
      tabSize: Double(formattingMetadata.tabSize),
      indentSize: Double(formattingMetadata.indentSize),
      usesTabsForIndentation: formattingMetadata.usesTabsForIndentation,
      uti: formattingMetadata.uti ?? "")

    // Convert selection to schema type
    let schemaSelection = Schema.CursorRange(
      start: Schema.CursorPosition(
        line: Double(selection.start.line),
        character: Double(selection.start.character)),
      end: Schema.CursorPosition(
        line: Double(selection.end.line),
        character: Double(selection.end.character)))

    let requestParams = Schema.CodeCompletionRequestParams(
      model: model,
      provider: provider,
      selection: schemaSelection,
      recentEdits: nil,
      pasteboardContent: pasteboardContent,
      formattingMetadata: schemaFormattingMetadata,
      prefix: prefix,
      suffix: suffix)

    let requestData = try JSONEncoder().encode(requestParams)

    let response: Schema.CodeCompletionResponseParams = try await localServer.postRequest(
      path: "completeCode",
      data: requestData)

    // Return first choice if available
    guard let firstChoice = response.choices.first else {
      return nil
    }

    if firstChoice.text != "" {
      print("??")
    }

    // For now, return the completion text as-is
    // In a full implementation, we would calculate proper start/end positions
    return RawCompletionSuggestion(
      file: file,
      startPosition: selection.start,
      endPosition: selection.start,
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

extension BaseProviding where Self: LocalServerProviding, Self: SettingsServiceProviding {
  public var mistralCodeCompletionProvider: CodeCompletionProvider {
    APIBasedCodeCompletionProvider(
      id: "mistral",
      displayName: "Mistral",
      model: "mistral-7b-instruct-v0.1.Q4_0.gguf",
      providerName: .mistral,
      localServer: localServer,
      settingsService: settingsService)
  }
}
