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
import SwiftUI

// MARK: - ChatInputView

@MainActor
struct ChatInputView: View {

  init(
    inputViewModel: ChatInputViewModel,
    isStreamingResponse: Binding<Bool>)
  {
    self.inputViewModel = inputViewModel
    _isStreamingResponse = isStreamingResponse
    #if DEBUG
    _debugTextViewHandler = nil
    #endif
  }

  #if DEBUG
  init(
    _debugTextViewHandler: @escaping @Sendable (NSTextView) -> Void,
    inputViewModel: ChatInputViewModel,
    isStreamingResponse: Binding<Bool>)
  {
    self.inputViewModel = inputViewModel
    _isStreamingResponse = isStreamingResponse
    self._debugTextViewHandler = _debugTextViewHandler
  }
  #endif

  static let cornerRadius: CGFloat = 10

  #if DEBUG
  let _debugTextViewHandler: (@Sendable (NSTextView) -> Void)?
  #endif

  var body: some View {
    VStack(spacing: 0) {
      if let pendingToolApproval = inputViewModel.pendingToolApproval {
        approvalView(for: pendingToolApproval)
      }
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 8) {
          AttachmentsView(
            searchAttachment: inputViewModel.handleStartExternalSearch,
            attachments: $inputViewModel.attachments)
        }
        .padding(.horizontal, sidePadding)
        .padding(.top, sidePadding)
        .isHidden(!enableAttachments, remove: true)
        textInput
        Rectangle()
          .foregroundColor(.clear)
          .frame(height: 6)
        bottomRow
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
          .readingSize { size in searchResultsViewHeight = size.height }
          .offset(y: -searchResultsViewHeight)
          .onOutsideTap {
            inputViewModel.handleCloseSearch()
          }
      }
    }
    .padding(8)
    .animation(.easeInOut, value: hasPendingToolApproval)
    .onTapGesture {
      inputViewModel.textInputNeedsFocus = true
    }
  }

  @State private var searchResultsViewHeight: CGFloat = 0

  @Environment(\.colorScheme) private var colorScheme

  /// Is a streaming chat response in progress
  @Binding private var isStreamingResponse: Bool

  @State private var scrollViewContentSize = CGSize.zero

  @Bindable private var inputViewModel: ChatInputViewModel

  private let sidePadding: CGFloat = 6

  private var enableAttachments: Bool {
    inputViewModel.pendingToolApproval == nil
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
    }
  }

  private var bottomRow: some View {
    HStack(alignment: .center, spacing: 6) {
      chatModeSelection
      PopUpSelectionMenu(
        selectedItem: $inputViewModel.selectedModel,
        availableItems: inputViewModel.activeModels,
        emptySelectionText: "No model configured",
        isExpanded: $inputViewModel.isModelSelectionExpanded)
      { model in
        Text(model.name)
      }
      HStack(spacing: 10) {
        Spacer()

        ImageAttachmentPickerView(attachments: $inputViewModel.attachments)
          .frame(width: 14, height: 14)
          .isHidden(!enableAttachments, remove: true)
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
          placeholder: "Write something here")
          .scrollContentBackground(.hidden)
          .fixedSize(horizontal: false, vertical: true)
          .onAppear {
            inputViewModel.textInputNeedsFocus = true
          }
          .padding(.vertical, 8)
          .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
          } action: { size in
            scrollViewContentSize = size
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
      inputViewModel.didCancelMessage()
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
    inputViewModel.handleDidTapSend()
  }

  private func onKeyDown(key: KeyEquivalent, modifiers: NSEvent.ModifierFlags) -> Bool {
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
}

// MARK: - LLMModel + MenuItem

extension LLMModel: MenuItem { }

// MARK: - ChatMode + MenuItem

extension ChatMode: MenuItem {
  public var id: String { rawValue }
}
