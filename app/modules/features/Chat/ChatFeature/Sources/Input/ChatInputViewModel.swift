// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import AppKit
import ChatFeatureInterface
import ChatFoundation
import Combine
import ConcurrencyFoundation
import Dependencies
import DLS
import FileSuggestionServiceInterface
import Foundation
import FoundationInterfaces
import LLMFoundation
import LoggingServiceInterface
import PDFKit
import SettingsServiceInterface
import SwiftUI
import ToolFoundation
import UniformTypeIdentifiers
import XcodeObserverServiceInterface

// MARK: - ToolApprovalRequest

/// Represents a request for user approval to execute a tool.
/// Used to display approval prompts and track pending tool execution requests.
struct ToolApprovalRequest: Identifiable {
  /// Unique identifier for the request, automatically generated.
  let id = UUID()
  /// Internal name of the tool requesting approval.
  let toolName: String
  /// User-friendly name of the tool to display in the approval UI.
  let displayName: String
}

// MARK: - ToolApprovalResult

enum ToolApprovalResult {
  case approved
  case denied
  case alwaysApprove
  case cancelled
}

// MARK: - PendingToolApproval

/// The current tool approvals request pending user response.
private struct PendingToolApproval {
  let request: ToolApprovalRequest
  let continuation: CheckedContinuation<ToolApprovalResult, Never>
}

// MARK: - ChatInputViewModel

@Observable @MainActor
final class ChatInputViewModel {

  #if DEBUG
  convenience init(
    selectedModel: LLMModel? = nil,
    activeModels: [LLMModel]? = nil,
    mode: ChatMode = .agent,
    attachments: [AttachmentModel] = [])
  {
    self.init(
      textInput: TextInput(),
      selectedModel: selectedModel,
      activeModels: activeModels,
      mode: mode,
      attachments: attachments)
  }
  #endif

  convenience init() {
    @Dependency(\.userDefaults) var userDefaults
    let selectedModel: LLMModel? =
      if let modelName = userDefaults.string(forKey: Self.userDefaultsSelectLLMModelKey) {
        LLMModel(rawValue: modelName)
      } else {
        nil
      }

    let chatMode: ChatMode =
      if let chatModeName = userDefaults.string(forKey: Self.userDefaultsChatModeKey) {
        ChatMode(rawValue: chatModeName) ?? .agent
      } else {
        .agent
      }

    self.init(
      textInput: TextInput(),
      selectedModel: selectedModel,
      activeModels: nil, // Pass nil here to signal that the value from settings should be observed.
      mode: chatMode,
      attachments: [])
  }

  /// - Parameters:
  ///   - activeModels: The available LLM models. When nil, this value is resolved from the settings and changes to the settings will be observed.
  private init(
    textInput: TextInput,
    selectedModel: LLMModel? = nil,
    activeModels: [LLMModel]?,
    mode: ChatMode = .agent,
    attachments: [AttachmentModel])
  {
    self.textInput = textInput
    self.selectedModel = selectedModel ?? activeModels?.first
    self.mode = mode
    self.attachments = attachments

    if let activeModels {
      self.activeModels = activeModels
      updateSelectedModel()
    } else {
      @Dependency(\.settingsService) var settingsService
      let settings = settingsService.liveValues()
      self.activeModels = settings.currentValue.activeModels
      updateSelectedModel()
      settingsService.liveValues().sink { [weak self] settings in
        guard let self else { return }
        self.activeModels = settings.activeModels
        updateSelectedModel()
      }.store(in: &cancellables)
    }

    searchTasks.sink { @Sendable [weak self] suggestions in
      Task { @MainActor in
        self?.searchResults = suggestions
      }
    }.store(in: &cancellables)
  }

  /// The list of available LLM models that can be selected.
  private(set) var activeModels: [LLMModel]
  /// Attachments selected by the user as explicit context for the next message.
  var attachments: [AttachmentModel]
  /// Whether the text input needs to be focused on. This will be reset to false once focus has been updated.
  var textInputNeedsFocus = false

  /// When searching for references, the index of the selected search result (at this point the selection has not yet been confirmed).
  var selectedSearchResultIndex = 0

  /// The suggested result for the current pending tool approval request.
  var pendingToolApprovalSuggestedResult = ToolApprovalResult.alwaysApprove

  var didTapSendMessage: @MainActor () -> Void = { }

  var didCancelMessage: @MainActor () -> Void = { }

  /// The current tool approval request pending user response.
  var pendingToolApproval: ToolApprovalRequest? { toolCallsPendingApproval.first?.request }

  /// Which LLM model is selected to respond to the next message.
  var selectedModel: LLMModel? {
    didSet {
      if let selectedModel {
        userDefaults.set(selectedModel.id, forKey: Self.userDefaultsSelectLLMModelKey)
      }
    }
  }

  /// The chat mode to use for this conversation.
  var mode: ChatMode {
    didSet {
      userDefaults.set(mode.rawValue, forKey: Self.userDefaultsChatModeKey)
    }
  }

  /// The input text, which can contain inline references to attachments.
  var textInput: TextInput {
    didSet {
      handleTextInputChange(from: oldValue)
    }
  }

  /// The results from the current reference search.
  private(set) var searchResults: [FileSuggestion]? = nil {
    didSet {
      if let searchResults {
        selectedSearchResultIndex = max(0, min(searchResults.count - 1, selectedSearchResultIndex))
      } else {
        selectedSearchResultIndex = 0
      }
    }
  }

  /// Whether the popup to select chat mode is shown
  var isChatModeSelectionExpanded = false {
    didSet {
      if isChatModeSelectionExpanded {
        // Close other popups
        isModelSelectionExpanded = false
      }
    }
  }

  /// Whether the popup to select LLM model is shown
  var isModelSelectionExpanded = false {
    didSet {
      if isModelSelectionExpanded {
        // Close other popups
        isChatModeSelectionExpanded = false
      }
    }
  }

  /// The search query, and related information, used to find references.
  var inlineSearch: (String, NSRange, CGRect?)? {
    didSet {
      if inlineSearch?.0 != oldValue?.0 {
        updateSearchResults(searchQuery: inlineSearch?.0)
      }
    }
  }

  var externalSearchQuery: String? {
    didSet {
      if externalSearchQuery != oldValue {
        updateSearchResults(searchQuery: externalSearchQuery)
      }
    }
  }

  /// Create a deep copy of the view model.
  func copy(
    didTapSendMessage: @escaping @MainActor () -> Void,
    didCancelMessage: @escaping @MainActor () -> Void)
    -> ChatInputViewModel
  {
    let model = ChatInputViewModel(
      textInput: TextInput(textInput.string),
      selectedModel: selectedModel,
      // Pass nil here to signal that the value from settings should be observed.
      // This method is not expected to be called in Previews where the mock settings might not have the right content.
      activeModels: nil,
      mode: mode,
      attachments: attachments)
    model.didTapSendMessage = didTapSendMessage
    model.didCancelMessage = didCancelMessage
    return model
  }

  func handleStartExternalSearch(isSearching: Bool) {
    if isSearching {
      externalSearchQuery = ""
    } else {
      externalSearchQuery = nil
    }
  }

  func handleCloseSearch() {
    clearSearchResults()
  }

  /// Handle sending the message.
  func handleDidTapSend() {
    didTapSendMessage()
  }

  /// Add an attachment to the input.
  @MainActor
  func add(attachment: AttachmentModel) {
    guard attachments.contains(where: { $0 === attachment }) == false else { return }
    attachments.append(attachment)
  }

  @MainActor
  func handleOnKeyDown(key: KeyEquivalent, modifiers: [KeyModifier]) -> Bool {
    if
      ![
        .leftArrow,
        .rightArrow,
        .downArrow,
        .upArrow,
        .return,
        .escape,
        .tab,
      ].contains(key)
    {
      return false
    }

    if let pendingToolApproval {
      return handle(key: key, modifiers: modifiers, for: pendingToolApproval)
    } else if let searchResults {
      return handle(key: key, modifiers: modifiers, for: searchResults)
    } else if isModelSelectionExpanded {
      return handle(keyForModelSelection: key, modifiers: modifiers)
    }

    if key == .tab, modifiers.contains(.shift) {
      // cycle chat modes
      if let idx = ChatMode.allCases.index(of: mode) {
        mode = ChatMode.allCases[(idx + 1) % ChatMode.allCases.count]
        return true
      }
    }
    if isChatModeSelectionExpanded {
      return handle(keyForChatModeSelection: key, modifiers: modifiers)
    }

    if key == .escape {
      didCancelMessage()
      return true
    }
    return false
  }

  func handleDrop(of item: MultiTypeTransferable) -> Bool {
    switch item {
    case .text(let text):
      textInput.append(text)

    case .image(let image):
      guard let imageData = image.pngData else {
        assertionFailure("Could not convert image to PNG data")
        return false
      }
      let attachment = AttachmentModel.image(.init(imageData: imageData, path: nil, mimeType: "image/png"))
      attachments.append(attachment)

    case .file(let url):
      if let attachment = createFileAttachment(from: url) {
        attachments.append(attachment)
      }
    }
    return true
  }

  func handleDidSelect(searchResult: FileSuggestion?) {
    defer {
      clearSearchResults()
    }

    guard let searchResult else { return }

    let attachment: AttachmentModel
    if
      let existingAttachment = attachments.first(where: { attachment in
        if case .file(let fileAttachment) = attachment {
          return fileAttachment.path == searchResult.path
        }
        return false
      })
    {
      attachment = existingAttachment
    } else {
      guard let fileAttachment = createFileAttachment(from: searchResult.path) else {
        return
      }
      attachment = fileAttachment
    }
    guard let inlineSearch else {
      // this is an external search.
      if !attachments.contains(where: { $0 === attachment }) {
        attachments.append(attachment)
      }
      return
    }

    inlineReferences[attachment.id.uuidString] = attachment
    let str = NSMutableAttributedString(attributedString: textInput.string)
    let reference = TextInput.Reference(display: "@\(searchResult.path.lastPathComponent)", id: attachment.id.uuidString)

    str.replaceCharacters(in: inlineSearch.1, with: reference.asReferenceBlock)
    str.append(NSAttributedString(string: " "))

    // We do not update `attachments` in this function as this is triggered by updating `textInput`.
    textInput = TextInput(str)
  }

  /// Request approval for a tool use operation.
  func requestApproval(for toolUse: any ToolUse) async -> ToolApprovalResult {
    await withCheckedContinuation { continuation in
      let request = ToolApprovalRequest(
        toolName: toolUse.toolName,
        displayName: toolUse.toolDisplayName)
      self.toolCallsPendingApproval.append(PendingToolApproval(request: request, continuation: continuation))
    }
  }

  /// Cancels all pending tool approval requests.
  /// We must clear the array before resuming continuations to prevent crashes from double-resumption if called multiple times.
  func cancelAllPendingToolApprovalRequests() {
    guard !toolCallsPendingApproval.isEmpty else { return }

    let pendingItems = toolCallsPendingApproval
    toolCallsPendingApproval.removeAll()
    pendingToolApprovalSuggestedResult = .alwaysApprove

    for item in pendingItems {
      item.continuation.resume(returning: .cancelled)
    }
  }

  /// Handle the user's approval response.
  func handleApproval(of request: ToolApprovalRequest, result: ToolApprovalResult? = nil) {
    let currentSuggestedResult = pendingToolApprovalSuggestedResult
    pendingToolApprovalSuggestedResult = .alwaysApprove

    let approvalResult = result ?? currentSuggestedResult
    guard let index = toolCallsPendingApproval.firstIndex(where: { $0.request.id == request.id }) else {
      defaultLogger.error("Could not find pending tool approval request with ID: \(request.id)")
      return
    }
    let pendingToolApproval = toolCallsPendingApproval.remove(at: index)
    pendingToolApproval.continuation.resume(returning: approvalResult)
  }

  private static let userDefaultsSelectLLMModelKey = "selectedLLMModel"
  private static let userDefaultsChatModeKey = "chatMode"

  /// Queue of tool approval requests waiting for user response.
  /// Each entry contains both the request details and the continuation that will receive the user's decision.
  private var toolCallsPendingApproval: [PendingToolApproval] = []

  /// References to attachments within the text input.
  @ObservationIgnored private var inlineReferences = [String: AttachmentModel]()

  @ObservationIgnored
  @Dependency(\.fileSuggestionService) private var fileSuggestionService

  @ObservationIgnored
  @Dependency(\.xcodeObserver) private var xcodeObserver

  @ObservationIgnored
  @Dependency(\.userDefaults) private var userDefaults

  @ObservationIgnored
  @Dependency(\.fileManager) private var fileManager

  private let searchTasks = ReplaceableTaskQueue<[FileSuggestion]?>()
  private var cancellables = Set<AnyCancellable>()

  private func handle(keyForModelSelection key: KeyEquivalent, modifiers _: [KeyModifier]) -> Bool {
    if key == .escape || key == .return {
      isModelSelectionExpanded = false
      return true
    }
    // VStack is ordered top to bottom, so ↓ increases idx
    if key == .downArrow, let selectedModel, let idx = activeModels.index(of: selectedModel) {
      if idx < activeModels.count - 1 {
        self.selectedModel = activeModels[idx + 1]
      }
      return true
    }
    if key == .upArrow, let selectedModel, let idx = activeModels.index(of: selectedModel) {
      if idx > 0 {
        self.selectedModel = activeModels[idx - 1]
      }
      return true
    }
    return false
  }

  private func handle(keyForChatModeSelection key: KeyEquivalent, modifiers _: [KeyModifier]) -> Bool {
    if key == .escape || key == .return {
      isChatModeSelectionExpanded = false
      return true
    }
    // VStack is ordered top to bottom, so ↓ increases idx
    if key == .downArrow, let idx = ChatMode.allCases.index(of: mode) {
      if idx < ChatMode.allCases.count - 1 {
        mode = ChatMode.allCases[idx + 1]
      }
      return true
    }
    if key == .upArrow, let idx = ChatMode.allCases.index(of: mode) {
      if idx > 0 {
        mode = ChatMode.allCases[idx - 1]
      }
      return true
    }
    return false
  }

  private func handle(
    key: KeyEquivalent,
    modifiers: [KeyModifier],
    for pendingToolApproval: ToolApprovalRequest)
    -> Bool
  {
    if key == .upArrow {
      switch pendingToolApprovalSuggestedResult {
      case .approved:
        pendingToolApprovalSuggestedResult = .alwaysApprove
      case .denied:
        pendingToolApprovalSuggestedResult = .approved
      default:
        break
      }
      return true
    } else if key == .downArrow {
      switch pendingToolApprovalSuggestedResult {
      case .alwaysApprove:
        pendingToolApprovalSuggestedResult = .approved
      case .approved:
        pendingToolApprovalSuggestedResult = .denied
      default:
        break
      }
      return true
    } else if key == .return, !modifiers.contains(.shift) {
      handleApproval(of: pendingToolApproval)
      return true
    }
    return false
  }

  private func handle(key: KeyEquivalent, modifiers: [KeyModifier], for searchResults: [FileSuggestion]) -> Bool {
    if key == .upArrow {
      selectedSearchResultIndex = max(0, selectedSearchResultIndex - 1)
      return true
    } else if key == .downArrow {
      selectedSearchResultIndex = min(searchResults.count - 1, selectedSearchResultIndex + 1)
      return true
    } else if key == .return, !modifiers.contains(.shift) {
      guard searchResults.count > selectedSearchResultIndex else {
        // Not searching, don't handle the key event.
        return false
      }
      // Handle search selection
      handleDidSelect(searchResult: searchResults[selectedSearchResultIndex])
      return true
    }
    return false
  }

  private func clearSearchResults() {
    updateSearchResults(searchQuery: nil)
    inlineSearch = nil
    externalSearchQuery = nil
  }

  private func createFileAttachment(from url: URL) -> AttachmentModel? {
    if UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true {
      guard let data = try? fileManager.read(dataFrom: url) else {
        assertionFailure("Could not read image data from \(url)")
        return nil
      }
      return AttachmentModel.image(.init(imageData: data, path: url, mimeType: "image/\(url.pathExtension)"))
    }
    guard let content = try? fileManager.read(contentsOf: url) else {
      assertionFailure("Could not read file at \(url)")
      return nil
    }
    return AttachmentModel.file(.init(path: url, content: content))
  }

  /// When the text input changes, detect which inline references have changed, and update the attachments accordingly.
  private func handleTextInputChange(from oldValue: TextInput) {
    let oldAttachments = oldValue.elements.compactMap(\.reference).compactMap { inlineReferences[$0.id] }
    let newAttachments = textInput.elements.compactMap(\.reference).compactMap { inlineReferences[$0.id] }

    let addedAttachments = newAttachments.filter { !oldAttachments.contains($0) }
    let removedAttachments = oldAttachments.filter { !newAttachments.contains($0) }

    for addedAttachment in addedAttachments { attachments.append(addedAttachment) }
    for attachment in removedAttachments {
      attachments.removeAll(where: { $0.id == attachment.id })
    }
  }

  /// When the search query has changed, update the search results accordingly.
  private func updateSearchResults(searchQuery: String?) {
    guard
      let searchQuery,
      let workspaceUrl = xcodeObserver.state.focusedWorkspace?.url
    else {
      searchResults = nil
      selectedSearchResultIndex = 0
      textInputNeedsFocus = true
      // Queue a nil value to clear the pending search results.
      searchTasks.queue { nil }

      return
    }
    let fileSuggestionService = fileSuggestionService
    searchTasks.queue {
      try await fileSuggestionService.suggestFiles(for: searchQuery, in: workspaceUrl, top: 50)
    }
  }

  private func updateSelectedModel() {
    if let selectedModel, activeModels.contains(selectedModel) {
      return
    }
    selectedModel = activeModels.first
  }
}

// MARK: - TextInput

struct TextInput {

  init(_ elements: [Element] = []) {
    self.elements = elements
  }

  enum Element {
    case text(_ text: String)
    case reference(_ reference: Reference)

    var reference: Reference? {
      if case .reference(let reference) = self {
        return reference
      }
      return nil
    }

    var text: String? {
      if case .text(let text) = self {
        return text
      }
      return nil
    }
  }

  struct Reference: Equatable {
    let display: String
    let id: String
  }

  var elements: [Element]

  var isEmpty: Bool {
    elements.isEmpty
  }

  mutating func append(_ str: String) {
    if case .text(let lastText) = elements.last {
      elements[elements.count - 1] = .text(lastText + str)
    } else {
      elements.append(.text(str))
    }
  }
}

extension NSImage {
  var pngData: Data? {
    guard let tiffData = tiffRepresentation else { return nil }
    let bitmap = NSBitmapImageRep(data: tiffData)
    return bitmap?.representation(using: .png, properties: [:])
  }
}
