// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import AppKit
import ChatFoundation
import Combine
import ConcurrencyFoundation
import Dependencies
import DLS
import LLMFoundation
import LoggingServiceInterface
import RoutingFoundation
import SettingsFeatureInterface
import SettingsServiceInterface
import SwiftUI

// MARK: - ChatInputConfig

/// Configuration for customizing the chat input view appearance and behavior.
public struct ChatInputConfig {
  public init(
    placeholderText: String = "Ask anything (⌘L), @ to mention",
    showChatMode: Bool = true,
    showAttachmentButton: Bool = true)
  {
    self.placeholderText = placeholderText
    self.showChatMode = showChatMode
    self.showAttachmentButton = showAttachmentButton
  }

  /// The placeholder text to display in the text input
  public let placeholderText: String
  /// Whether to show the chat mode selector (agent/ask)
  public let showChatMode: Bool
  /// Whether to show the @ attachment button
  public let showAttachmentButton: Bool
}

// MARK: - ContextControlsConfig

/// Configuration for context usage controls in the chat input view.
public struct ContextControlsConfig {
  public init(
    tokenUsage: TokenUsageEvent?,
    isCompacting: Bool,
    onCompact: @escaping @MainActor () async -> Void,
    compactIconURL: URL? = nil)
  {
    self.tokenUsage = tokenUsage
    self.isCompacting = isCompacting
    self.onCompact = onCompact
    self.compactIconURL = compactIconURL
  }

  /// The latest token usage information to display
  public let tokenUsage: TokenUsageEvent?
  /// Whether a conversation compaction is currently in progress
  public let isCompacting: Bool
  /// Action to perform when the compact button is tapped
  public let onCompact: @MainActor () async -> Void
  /// URL to the compact icon resource
  public let compactIconURL: URL?

}

// MARK: - ChatInputView

@MainActor
public struct ChatInputView: View {

  public init(
    inputViewModel: ChatInputViewModel,
    config: ChatInputConfig = ChatInputConfig(),
    contextControlsConfig: ContextControlsConfig? = nil,
    isStreamingResponse: Binding<Bool>)
  {
    self.inputViewModel = inputViewModel
    self.config = config
    self.contextControlsConfig = contextControlsConfig
    _isStreamingResponse = isStreamingResponse
    #if DEBUG
    _debugTextViewHandler = nil
    #endif
  }

  #if DEBUG
  init(
    _debugTextViewHandler: @escaping @Sendable (NSTextView) -> Void,
    inputViewModel: ChatInputViewModel,
    config: ChatInputConfig = ChatInputConfig(),
    contextControlsConfig: ContextControlsConfig? = nil,
    isStreamingResponse: Binding<Bool>)
  {
    self.inputViewModel = inputViewModel
    self.config = config
    self.contextControlsConfig = contextControlsConfig
    _isStreamingResponse = isStreamingResponse
    self._debugTextViewHandler = _debugTextViewHandler
  }
  #endif

  public var body: some View {
    VStack(spacing: 0) {
      if let pendingToolApproval = inputViewModel.pendingToolApproval {
        approvalView(for: pendingToolApproval)
      }
      // Queued messages view
      QueuedMessagesView(
        queuedMessages: $inputViewModel.queuedMessages,
        isExpanded: $isQueueExpanded,
        onSendNow: inputViewModel.sendQueuedMessageNow,
        onDelete: inputViewModel.deleteQueuedMessage)
        .padding(.horizontal, sidePadding)
        .padding(.bottom, 8)
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 8) {
          AttachmentsView(
            searchAttachment: inputViewModel.handleStartExternalSearch,
            attachments: $inputViewModel.attachments)
        }
        .padding(.horizontal, sidePadding)
        .padding(.top, sidePadding)
        .isHidden(!shouldShowAttachmentsRow, remove: true)
        textInput
        Rectangle()
          .foregroundColor(.clear)
          .frame(height: 6)
        bottomRow
      }
      .overlay(alignment: .topTrailing) {
        // Context usage controls positioned at top right
        if shouldShowContextControls {
          contextUsageControls
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
      }
      .overlay {
        DragDropAreaView(
          shape: AnyShape(RoundedRectangle(cornerRadius: Self.cornerRadius)),
          handleDrop: inputViewModel.handleDrop)
      }
      .with(
        cornerRadius: Self.cornerRadius,
        backgroundColor: colorScheme.xcodeInputBackground,
        borderColor: colorScheme.textAreaBorderColor)
    }
    .overlay(alignment: .top) {
      if let searchResults = inputViewModel.searchResults {
        SearchResultsView(
          selectedRowIndex: $inputViewModel.selectedSearchResultIndex,
          results: searchResults,
          didSelect: inputViewModel.handleDidSelect,
          searchInput: $inputViewModel.externalSearchQuery)
          .readingSize { size in
            if abs(size.height - searchResultsViewHeight) > 0.5 {
              print("setting searchResultsViewHeight")
              searchResultsViewHeight = size.height
            }
          }
          .offset(y: -searchResultsViewHeight)
          .onOutsideTap {
            inputViewModel.handleCloseSearch()
          }
      }
    }
    .animation(.easeInOut, value: hasPendingToolApproval)
    .onTapGesture {
      inputViewModel.textInputNeedsFocus = true
    }
  }

  static let cornerRadius: CGFloat = 10

  #if DEBUG
  let _debugTextViewHandler: (@Sendable (NSTextView) -> Void)?
  #endif

  @State private var searchResultsViewHeight: CGFloat = 0

  @State private var isHoveringContextIndicator = false

  @State private var isQueueExpanded = true

  @Environment(\.colorScheme) private var colorScheme

  /// Is a streaming chat response in progress
  @Binding private var isStreamingResponse: Bool

  @State private var scrollViewContentSize = CGSize.zero

  @Bindable private var inputViewModel: ChatInputViewModel

  @Environment(Router.self) private var router

  @Dependency(\.settingsService) private var settingsService

  private let config: ChatInputConfig

  private let contextControlsConfig: ContextControlsConfig?

  @Dependency(\.llmService) private var llmService

  private let sidePadding: CGFloat = 6

  private var enableAttachments: Bool {
    inputViewModel.pendingToolApproval == nil
  }

  private var shouldShowAttachmentsRow: Bool {
    guard enableAttachments else { return false }
    // If attachment button is shown, always show the row
    if config.showAttachmentButton {
      return true
    }
    // If attachment button is hidden, only show row when there are attachments
    return !inputViewModel.attachments.isEmpty
  }

  private var isInputReady: Bool {
    !inputViewModel.textInput.isEmpty
  }

  private var textInput: some View {
    VStack {
      HStack(alignment: .center, spacing: sidePadding) {
        chatInputTextEditor
      }
    }
    .padding(.top, 4)
    .padding(.horizontal, sidePadding)
  }

  private var chatModeSelection: some View {
    PopUpSelectionMenu(
      selectedItem: $inputViewModel.mode,
      availableItems: ChatMode.allCases,
      isExpanded: $inputViewModel.isChatModeSelectionExpanded)
    { mode in
      switch mode {
      case .agent:
        AgentModeView()
      case .ask:
        AskModeView()
      }
    } bottomRow: {
      HStack {
        Button {
          router.navigate(to: ChatModeSettingsRoute())
        } label: {
          Text("Configure")
            .font(.caption)
            .foregroundColor(.secondary)
            .underline()
        }
        .buttonStyle(.plain)
        .padding(3)
        Spacer()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var bottomRow: some View {
    HStack(alignment: .center, spacing: 6) {
      if config.showChatMode {
        chatModeSelection
      }
      PopUpSelectionMenu(
        selectedItem: $inputViewModel.selectedModel,
        availableItems: inputViewModel.activeModels,
        searchKey: inputViewModel.activeModels.count > 5 ? { item in item.name } : nil,
        emptySelectionText: "No model configured",
        isExpanded: $inputViewModel.isModelSelectionExpanded,
        maxHeight: 200)
      { model in
        Text(model.name)
      }
      HStack(spacing: 10) {
        Spacer()

        if config.showAttachmentButton {
          ImageAttachmentPickerView(attachments: $inputViewModel.attachments)
            .frame(width: 14, height: 14)
            .isHidden(!enableAttachments, remove: true)
        }
        if isStreamingResponse, !hasPendingToolApproval {
          stopButton
        } else {
          sendButton
        }
      }
      .padding(.bottom, 4)
    }
    .padding(.bottom, 4)
    .padding(.horizontal, 8)
  }

  private var chatInputTextEditor: some View {
    VStack(alignment: .leading) {
      ScrollView([.vertical]) {
        RichTextEditor(
          text: Binding<NSAttributedString>(
            get: { inputViewModel.textInput.string },
            set: { inputViewModel.textInput = TextInput($0) }),
          needsFocus: $inputViewModel.textInputNeedsFocus,
          onFocusChanged: { isFocused in
            if inputViewModel.textInputNeedsFocus, isFocused {
              inputViewModel.textInputNeedsFocus = false
            }
          },
          onSearch: { search in
            inputViewModel.inlineSearch = search
          },
          onKeyDown: { key, modifiers in onKeyDown(key: key, modifiers: modifiers) },
          placeholder: config.placeholderText)
          .scrollContentBackground(.hidden)
          .fixedSize(horizontal: false, vertical: true)
          .onAppear {
            inputViewModel.textInputNeedsFocus = true
          }
          .padding(.vertical, 8)
          .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
          } action: { size in
            if abs(size.width - scrollViewContentSize.width) > 0.5 || abs(size.height - scrollViewContentSize.height) > 0.5 {
              scrollViewContentSize = size
            }
          }
      }
    }.defaultScrollAnchor(.bottom)
      .frame(maxHeight: scrollViewHeight)
  }

  private var scrollViewHeight: CGFloat {
    min(200, scrollViewContentSize.height)
  }

  private var stopButton: some View {
    Button(action: {
      inputViewModel.didCancelMessage(true)
    }) {
      Image(systemName: "stop.circle.fill")
        .tappableTransparentBackground()
    }
    .acceptClickThrough()
    .buttonStyle(.plain)
    .foregroundColor(.primary)
    .id("stop button")
  }

  private var sendButton: some View {
    Button(action: {
      sendIfReady()
    }) {
      HStack(spacing: 2) {
        if hasPendingToolApproval {
          switch inputViewModel.pendingToolApprovalSuggestedResult {
          case .alwaysApprove:
            Text("Always")
          case .approved:
            Text("Once")
          case .denied:
            Text("Deny")
          case .cancelled:
            Text("Cancel")
          }
        }
        Image(systemName: "return")
      }
      .tappableTransparentBackground()
    }
    .acceptClickThrough()
    .buttonStyle(.plain)
    .foregroundColor(isInputReady || hasPendingToolApproval ? .primary : .secondary)
    .id("chat button")
  }

  private var hasPendingToolApproval: Bool {
    inputViewModel.pendingToolApproval != nil
  }

  // MARK: - Context Usage Controls

  /// Whether to show context usage controls
  private var shouldShowContextControls: Bool {
    guard let config = contextControlsConfig, config.tokenUsage != nil else { return false }
    guard let selectedModel = inputViewModel.selectedModel else { return false }
    // Don't show controls when chatting with external agent
    let provider = llmService.provider(for: selectedModel).value
    return !(provider?.isExternalAgent ?? false)
  }

  @ViewBuilder
  private var contextUsageControls: some View {
    if let config = contextControlsConfig, let tokenUsage = config.tokenUsage, let model = inputViewModel.selectedModel {
      HStack(spacing: 6) {
        // Show compact button only on hover
        if isHoveringContextIndicator, let compactIconURL = config.compactIconURL {
          Button(action: {
            Task {
              await config.onCompact()
            }
          }) {
            SVGImage(compactIconURL)
              .frame(width: 14, height: 14)
          }
          .tappableTransparentBackground()
          .acceptClickThrough()
          .buttonStyle(.plain)
          .foregroundColor(.primary)
          .disabled(config.isCompacting)
          .transition(.opacity.combined(with: .move(edge: .trailing)))
        }

        CircularProgressIndicator(
          progress: tokenUsage.usageRatio(for: model),
          size: 20)
      }
      .overlay(alignment: .bottomTrailing) {
        if isHoveringContextIndicator {
          tokenUsageDetailsOverlay(tokenUsage: tokenUsage, model: model)
            .fixedSize(horizontal: true, vertical: true)
            .offset(x: 0, y: -32)
        }
      }
      .onHover { hovering in
        withAnimation(.easeInOut(duration: 0.2)) {
          isHoveringContextIndicator = hovering
        }
      }
    }
  }

  private func approvalView(for pendingToolApproval: ToolApprovalRequest) -> some View {
    ToolApprovalView(
      request: pendingToolApproval,
      suggestedResult: $inputViewModel.pendingToolApprovalSuggestedResult,
      onApprovalResult: { result in
        inputViewModel.handleApproval(of: pendingToolApproval, result: result)
      })
      .with(
        cornerRadius: Self.cornerRadius,
        corners: [.topLeft, .topRight],
        backgroundColor: colorScheme.xcodeInputBackground,
        borderColor: colorScheme.textAreaBorderColor)
      .padding(.horizontal, 10)
      .transition(
        .asymmetric(
          insertion: .move(edge: .bottom).combined(with: .opacity),
          removal: .move(edge: .bottom).combined(with: .opacity)))
  }

  private func sendIfReady() {
    if let pendingToolApproval = inputViewModel.pendingToolApproval {
      inputViewModel.handleApproval(of: pendingToolApproval)
      return
    }

    guard isInputReady else {
      return
    }

    // If currently streaming and queuing is enabled, queue the message instead of sending
    if isStreamingResponse, settingsService.values().queueMessagesWhileStreaming {
      inputViewModel.queueCurrentMessage()
    } else {
      inputViewModel.handleDidTapSend()
    }
  }

  private func onKeyDown(key: KeyEquivalent, modifiers: [KeyModifier]) -> Bool {
    // The input view gets to handle the key event first
    if inputViewModel.handleOnKeyDown(key: key, modifiers: modifiers) {
      return true
    }
    if key == .return, !modifiers.contains(.shift) {
      sendIfReady()
      return true
    }
    return false
  }

  @ViewBuilder
  private func tokenUsageDetailsOverlay(tokenUsage: TokenUsageEvent, model: AIModel) -> some View {
    VStack(alignment: .trailing, spacing: 4) {
      Text("Context Usage")
        .font(.caption.weight(.semibold))
      Text("\(tokenUsage.totalTokens.formatted()) / \(model.contextSize.formatted())")
        .font(.caption2)
      Text("\(Int(tokenUsage.usageRatio(for: model) * 100))% used")
        .font(.caption2)
    }
    .padding(8)
    .with(cornerRadius: 6, backgroundColor: colorScheme.secondarySystemBackground)
  }
}

// MARK: - AIModel + MenuItem

extension AIModel: MenuItem { }

// MARK: - ChatMode + MenuItem

extension ChatMode: MenuItem {
  public var id: String { rawValue }
}
