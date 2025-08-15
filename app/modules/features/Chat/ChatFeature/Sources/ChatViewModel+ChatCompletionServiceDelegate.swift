// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatCompletionServiceInterface
@preconcurrency import Combine
import ConcurrencyFoundation
import Dependencies
import Foundation
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
    @Dependency(\.xcodeObserver) var xcodeObserver
    let projectRoot = xcodeObserver.state.focusedWorkspace?.url

    thread.add(
      messageContents: chatCompletion.newUserMessages.map { .text(.init(projectRoot: projectRoot, text: $0)) },
      role: .user)
    defer { Task { await thread.sendMessage() } }
    let preExistingEventIds = Set<String>(thread.events.map(\.id))

    return AsyncStream<[ChatCompletionServiceInterface.ChatEvent]> { continuation in
      var cancellable: AnyCancellable?

      cancellable = thread.observeChanges(of: { thread in
        MainActor.assumeIsolated { (thread.events.newEvents(after: preExistingEventIds), thread.isStreamingResponse) }
      }).sink { @Sendable newEvents, isStreamingResponse in
        Task { @MainActor in
          continuation.yield(newEvents)
          if !isStreamingResponse {
            cancellable?.cancel()
            continuation.finish()
          }
        }
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
    self.filter { !preExistingEventIds.contains($0.id) }
      .compactMap { event in
        switch event {
        case .checkpoint:
          break
        case .message(let message):
          switch message.content {
          case .text(let text):
            if text.isStreaming {
              return nil
            }
            return .init(id: event.id, content: text.text)

          default:
            break
          }
        }
        return nil
      }
  }
}
