// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatCompletionServiceInterface
import ChatFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Dependencies
import Foundation
import LLMFoundation
import XcodeObserverServiceInterface

// MARK: - ChatViewModel + ChatCompletionServiceDelegate

extension ChatViewModel: ChatCompletionServiceDelegate {
  public func handle(chatCompletion: ChatCompletionInput) async throws
    -> AsyncStream<[ChatCompletionServiceInterface.ChatEvent]>
  {
    guard let threadId = UUID(uuidString: chatCompletion.threadId) else {
      throw AppError("The provided threadId \(chatCompletion.threadId) is not a valid UUID")
    }
    let thread = try await loadThread(withId: threadId)
    thread.input.selectedModel = llmService.activeModels.currentValue.first(where: { $0.name == chatCompletion.modelName })
    @Dependency(\.xcodeObserver) var xcodeObserver
    let projectRoot = xcodeObserver.state.focusedWorkspace?.url

    thread.add(
      messageContents: chatCompletion.newUserMessages.map { .text(.init(projectRoot: projectRoot, text: $0)) },
      role: .user)
    defer { Task { await thread.sendMessage() } }
    let preExistingEventIds = Set<String>(thread.events.map(\.id))

    return AsyncStream<[ChatCompletionServiceInterface.ChatEvent]> { continuation in
      let cancellable = thread.observeChanges(of: { thread in
        MainActor.assumeIsolated { (thread.events.newEvents(after: preExistingEventIds), thread.isStreamingResponse) }
      }).sink { @Sendable newEvents, isStreamingResponse in
        Task { @MainActor in
          continuation.yield(newEvents)
          if !isStreamingResponse {
            continuation.finish()
          }
        }
      }

      continuation.onTermination = { @Sendable _ in
        Task { @MainActor in
          thread.cancelCurrentMessage()
        }
        cancellable.cancel()
      }
    }
  }

  private func loadThread(withId threadId: UUID) async throws -> ChatThreadViewModel {
    if tab.id != threadId {
      // Try to load an existing thread.
      if let thread = try await chatHistoryService.loadChatThread(id: threadId) {
        tab = ChatThreadViewModel(from: thread)
      } else {
        // Create new thread
        addTab(copyingCurrentInput: false, threadId: threadId)
      }
    }
    return tab
  }
}

extension [ChatEvent] {
  @MainActor
  func newEvents(after preExistingEventIds: Set<String>) -> [ChatCompletionServiceInterface.ChatEvent] {
    filter { !preExistingEventIds.contains($0.id) }
      .compactMap { event in
        switch event {
        case .checkpoint:
          break
        case .message(let message):
          if let streamRepresentation = message.content.streamRepresentation {
            return .init(id: event.id, content: streamRepresentation)
          }
        }
        return nil
      }
  }
}

// MARK: - ChatMessageContent + StreamRepresentable

extension ChatMessageContent: StreamRepresentable {
  @MainActor
  var streamRepresentation: String? {
    switch self {
    case .conversationSummary:
      return nil

    case .internalContent:
      return nil

    case .nonUserFacingText:
      return nil

    case .reasoning(let reasoning):
      if reasoning.isStreaming { return nil }
      return reasoning.text.withTrailingNewline

    case .text(let text):
      if text.isStreaming { return nil }
      return text.text.withTrailingNewline

    case .toolUse(let toolUse):
      if let streamableToolUse = toolUse.toolUse as? (any StreamRepresentable) {
        return streamableToolUse.streamRepresentation?.withTrailingNewline
      } else {
        return nil
      }
    }
  }
}

extension String {
  var withTrailingNewline: String {
    if last == "\n" {
      return self
    }
    return self + "\n"
  }
}
