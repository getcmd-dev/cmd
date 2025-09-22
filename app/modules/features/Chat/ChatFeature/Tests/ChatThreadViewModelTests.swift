// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppEventServiceInterface
import ChatFeatureInterface
import Combine
import ConcurrencyFoundation
import Dependencies
import DependenciesTestSupport
import ExtensionEventsInterface
import Foundation
import LLMServiceInterface
import LocalServerServiceInterface
import SharedValuesFoundation
import SwiftTesting
import Testing
import XcodeObserverServiceInterface
@testable import ChatFeature

// MARK: - ChatThreadViewModelTests

struct ChatThreadViewModelTests {

  // MARK: - App Event Registry Tests

  @MainActor
  @Test("View model registers handler with app event registry on initialization")
  func viewModelRegistersHandlerWithAppEventRegistry() async throws {
    // Setup
    let mockEventRegistry = MockAppEventHandlerRegistry()
    let handlerRegistered = Atomic<Bool>(false)

    mockEventRegistry.onRegisterHandler = { _ in
      handlerRegistered.set(to: true)
    }

    // when
    let sut = withDependencies {
      $0.appEventHandlerRegistry = mockEventRegistry
    } operation: {
      ChatThreadViewModel()
    }

    // then
    #expect(handlerRegistered.value == true)
    _ = sut // Keep reference
  }

  @MainActor
  @Test("View model handles set_conversation_name command correctly")
  func viewModelHandlesSetConversationNameCommand() async throws {
    // given
    let mockEventRegistry = MockAppEventHandlerRegistry()
    let registeredHandler = Atomic<(@Sendable (AppEvent) async -> Bool)?>(nil)

    mockEventRegistry.onRegisterHandler = { handler in
      registeredHandler.set(to: handler)
    }

    let sut = withDependencies {
      $0.appEventHandlerRegistry = mockEventRegistry
    } operation: {
      ChatThreadViewModel()
    }

    let expectedName = "New Thread Name"
    let nameParams = Schema.NameConversationCommandParams(
      name: expectedName,
      threadId: sut.id.uuidString)
    let extensionRequest = ExtensionRequest(
      command: "set_conversation_name",
      input: nameParams)
    let requestData = try JSONEncoder().encode(extensionRequest)

    let event = ExecuteExtensionRequestEvent(
      command: "set_conversation_name",
      id: UUID().uuidString,
      data: requestData,
      completion: { _ in })

    // when
    let handled = await registeredHandler.value?(event)

    // then
    #expect(handled == true)
    #expect(sut.name == expectedName)
  }

  @MainActor
  @Test("View model ignores set_conversation_name command for different thread")
  func viewModelIgnoresSetConversationNameCommandForDifferentThread() async throws {
    // given
    let mockEventRegistry = MockAppEventHandlerRegistry()
    let registeredHandler = Atomic<(@Sendable (AppEvent) async -> Bool)?>(nil)

    mockEventRegistry.onRegisterHandler = { handler in
      registeredHandler.set(to: handler)
    }

    let sut = withDependencies {
      $0.appEventHandlerRegistry = mockEventRegistry
    } operation: {
      ChatThreadViewModel()
    }

    // Prepare test data with different thread ID
    let nameParams = Schema.NameConversationCommandParams(
      name: "New Thread Name",
      threadId: UUID().uuidString, // Different from sut.id
    )
    let extensionRequest = ExtensionRequest(
      command: "set_conversation_name",
      input: nameParams)
    let requestData = try JSONEncoder().encode(extensionRequest)

    let event = ExecuteExtensionRequestEvent(
      command: "set_conversation_name",
      id: UUID().uuidString,
      data: requestData,
      completion: { _ in })

    // when
    let handled = await registeredHandler.value?(event)

    // then
    #expect(handled == false)
    #expect(sut.name == nil) // Name should remain unchanged
  }

  @MainActor
  @Test("View model ignores non-set_conversation_name commands")
  func viewModelIgnoresNonSetConversationNameCommands() async throws {
    // Setup
    let mockEventRegistry = MockAppEventHandlerRegistry()
    let registeredHandler = Atomic<(@Sendable (AppEvent) async -> Bool)?>(nil)

    mockEventRegistry.onRegisterHandler = { handler in
      registeredHandler.set(to: handler)
    }

    let sut = withDependencies {
      $0.appEventHandlerRegistry = mockEventRegistry
    } operation: {
      ChatThreadViewModel()
    }

    // Prepare test data with different command
    let event = ExecuteExtensionRequestEvent(
      command: "different_command",
      id: UUID().uuidString,
      data: Data(),
      completion: { _ in })

    // when
    let handled = await registeredHandler.value?(event)

    // then
    #expect(handled == false)
    #expect(sut.name == nil) // Name should remain unchanged
  }

  @MainActor
  @Test("View model handles non-ExecuteExtensionRequestEvent events")
  func viewModelHandlesNonExecuteExtensionRequestEventEvents() async throws {
    // Setup
    let mockEventRegistry = MockAppEventHandlerRegistry()
    let registeredHandler = Atomic<(@Sendable (AppEvent) async -> Bool)?>(nil)

    mockEventRegistry.onRegisterHandler = { handler in
      registeredHandler.set(to: handler)
    }

    let sut = withDependencies {
      $0.appEventHandlerRegistry = mockEventRegistry
    } operation: {
      ChatThreadViewModel()
    }

    // Create a custom event that is not ExecuteExtensionRequestEvent
    struct CustomEvent: AppEvent { }
    let event = CustomEvent()

    // when
    let handled = await registeredHandler.value?(event)

    // then
    #expect(handled == false)
    _ = sut // Keep reference
  }

  @MainActor
  @Test("receiving messages updates state")
  func test_receivingMessages_updatesState() async throws {
    // given
    let mockLLMService = MockLLMService()

    let testThreadId = UUID()

    let sut = withDependencies {
      $0.withAllModelAvailable()
      $0.llmService = mockLLMService
    } operation: {
      ChatThreadViewModel(id: testThreadId)
    }

    let isDoneStreaming = expectation(description: "is done streaming")
    let hasProcessedFirstMessage = expectation(description: "has processed first message")

    mockLLMService.onSendMessage = { _, _, _, _, _, handleUpdateStream in
      let updateStream = MutableCurrentValueStream<[CurrentValueStream<AssistantMessage>]>([])
      handleUpdateStream(updateStream)

      let message = MutableCurrentValueStream<AssistantMessage>(.init(content: []))
      updateStream.update(with: [message])

      let firstTextContent = MutableCurrentValueStream<TextContentMessage>(.init(content: "", deltas: []))
      message.update(with: AssistantMessage(content: [.text(firstTextContent)]))
      firstTextContent.update(with: .init(content: "hello", deltas: ["hello"]))
      firstTextContent.finish()

      try await fulfillment(of: hasProcessedFirstMessage)

      let secondTextContent = MutableCurrentValueStream<TextContentMessage>(.init(content: "", deltas: []))
      message.update(with: AssistantMessage(content: [.text(firstTextContent), .text(secondTextContent)]))
      secondTextContent.update(with: .init(content: "world", deltas: ["world"]))
      secondTextContent.finish()

      message.finish()
      updateStream.finish()

      return SendMessageResponse(newMessages: [], usageInfo: nil)
    }

    var cancellables = Set<AnyCancellable>()

    let eventsHistory = Atomic<[[String]]>([])
    sut.observeChanges(to: \.events) { value in
      MainActor.assumeIsolated {
        let newValue = value.compactMap { $0.message?.content.asText?.text }
        eventsHistory.mutate { events in
          if events.last != newValue {
            events.append(newValue)
          }
          return events
        }
        if value.count == 2 {
          hasProcessedFirstMessage.fulfillAtMostOnce()
        }
        if value.count == 3 {
          isDoneStreaming.fulfillAtMostOnce()
        }
      }
    }.store(in: &cancellables)

    // when
    sut.input.textInput = .init(NSAttributedString(string: "sup?"))
    await sut.sendMessage()

    // then
    try await fulfillment(of: isDoneStreaming)
    #expect(eventsHistory.value == [["sup?"], ["sup?", "hello"], ["sup?", "hello", "world"]])

    // Clean up
    _ = cancellables
  }

  // MARK: - Focused File Tracking Tests

  @MainActor
  @Test("sendMessage includes focussed file")
  func sendMessageIncludesFocussedFile() async throws {
    // given
    let mockLLMService = MockLLMService()
    let messagesSent = Atomic<[Schema.Message]>([])

    mockLLMService.onSendMessage = { messages, _, _, _, _, _ in
      messagesSent.set(to: messages)
      return SendMessageResponse(newMessages: [], usageInfo: nil)
    }

    let workspaceURL = URL(fileURLWithPath: "/Users/test/MyProject")
    let fileURL = URL(fileURLWithPath: "/Users/test/MyProject/File.swift")
    let sut = withDependencies {
      $0.withAllModelAvailable()
      $0.xcodeObserver = MockXcodeObserver(workspaceURL: workspaceURL, focussedTabURL: fileURL)
      $0.llmService = mockLLMService
    } operation: {
      ChatThreadViewModel()
    }

    // when
    sut.input.textInput = .init(NSAttributedString(string: "How do I fix this?"))
    await sut.sendMessage()

    // then
    let sentMessages = messagesSent.value
    #expect(sentMessages.count == 2)
    #expect(sentMessages.map { $0.content.map(\.text) } == [
      ["The file currently focused in the editor is: /Users/test/MyProject/File.swift"],
      ["How do I fix this?"],
    ])
  }

  @MainActor
  @Test("sendMessage includes focussed file only once if it doesn't change")
  func sendMessageIncludesFocussedFileOnlyOnceIfItDoesNotChange() async throws {
    // given
    let mockLLMService = MockLLMService()
    let messagesSent = Atomic<[Schema.Message]>([])

    mockLLMService.onSendMessage = { messages, _, _, _, _, _ in
      messagesSent.set(to: messages)
      return SendMessageResponse(newMessages: [], usageInfo: nil)
    }

    let workspaceURL = URL(fileURLWithPath: "/Users/test/MyProject")
    let fileURL = URL(fileURLWithPath: "/Users/test/MyProject/File.swift")
    let sut = withDependencies {
      $0.withAllModelAvailable()
      $0.xcodeObserver = MockXcodeObserver(workspaceURL: workspaceURL, focussedTabURL: fileURL)
      $0.llmService = mockLLMService
    } operation: {
      ChatThreadViewModel()
    }

    // when
    sut.input.textInput = .init(NSAttributedString(string: "How do I fix this?"))
    await sut.sendMessage()
    sut.input.textInput = .init(NSAttributedString(string: "Thanks"))
    await sut.sendMessage()

    // then
    let sentMessages = messagesSent.value
    #expect(sentMessages.map { $0.content.map(\.text) } == [
      ["The file currently focused in the editor is: /Users/test/MyProject/File.swift"],
      ["How do I fix this?"],
      ["Thanks"],
    ])
  }

  @MainActor
  @Test("sendMessage includes focussed file twice if it changed")
  func sendMessageIncludesFocussedFileTwiceIfItChanged() async throws {
    // given
    let mockLLMService = MockLLMService()
    let messagesSent = Atomic<[Schema.Message]>([])

    mockLLMService.onSendMessage = { messages, _, _, _, _, _ in
      messagesSent.set(to: messages)
      return SendMessageResponse(newMessages: [], usageInfo: nil)
    }
    let workspaceURL = URL(fileURLWithPath: "/Users/test/MyProject")
    let fileURL = URL(fileURLWithPath: "/Users/test/MyProject/File.swift")
    let otherFileURL = URL(fileURLWithPath: "/Users/test/MyProject/OtherFile.swift")
    let mockXcodeObserver = MockXcodeObserver(workspaceURL: workspaceURL, focussedTabURL: fileURL)

    let sut = withDependencies {
      $0.withAllModelAvailable()
      $0.xcodeObserver = mockXcodeObserver
      $0.llmService = mockLLMService
    } operation: {
      ChatThreadViewModel()
    }

    // when
    sut.input.textInput = .init(NSAttributedString(string: "How do I fix this?"))
    await sut.sendMessage()
    let xcodeWorkspaceState = try #require(mockXcodeObserver.state.wrapped?.xcodesState.first?.workspaces.first)
    mockXcodeObserver.mutableStatePublisher.send(.state(
      XcodeState(
        activeApplicationProcessIdentifier: 1,
        previousApplicationProcessIdentifier: nil,
        xcodesState: [
          XcodeAppState(processIdentifier: 1, isActive: true, workspaces: [
            XcodeWorkspaceState(
              axElement: xcodeWorkspaceState.axElement,
              url: workspaceURL,
              editors: [],
              isFocused: true,
              document: nil,
              tabs: [.init(
                fileName: otherFileURL.lastPathComponent,
                isFocused: true,
                knownPath: otherFileURL,
                lastKnownContent: nil)]),
          ]),
        ])))
    sut.input.textInput = .init(NSAttributedString(string: "Thanks"))
    await sut.sendMessage()

    // then
    let sentMessages = messagesSent.value
    #expect(sentMessages.map { $0.content.map(\.text) } == [
      ["The file currently focused in the editor is: /Users/test/MyProject/File.swift"],
      ["How do I fix this?"],
      ["The file currently focused in the editor is: /Users/test/MyProject/OtherFile.swift"],
      ["Thanks"],
    ])
  }

}
