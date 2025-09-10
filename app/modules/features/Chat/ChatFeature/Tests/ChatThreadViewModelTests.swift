// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppEventServiceInterface
import ConcurrencyFoundation
import Dependencies
import ExtensionEventsInterface
import Foundation
import LocalServerServiceInterface
import SharedValuesFoundation
import SwiftTesting
import Testing
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

    // Test
    let sut = withDependencies {
      $0.appEventHandlerRegistry = mockEventRegistry
    } operation: {
      ChatThreadViewModel()
    }

    // Assert
    #expect(handlerRegistered.value == true)
    _ = sut // Keep reference
  }

  @MainActor
  @Test("View model handles set_conversation_name command correctly")
  func viewModelHandlesSetConversationNameCommand() async throws {
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

    // Prepare test data
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

    // Test
    let handled = await registeredHandler.value?(event)

    // Assert
    #expect(handled == true)
    #expect(sut.name == expectedName)
  }

  @MainActor
  @Test("View model ignores set_conversation_name command for different thread")
  func viewModelIgnoresSetConversationNameCommandForDifferentThread() async throws {
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

    // Test
    let handled = await registeredHandler.value?(event)

    // Assert
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

    // Test
    let handled = await registeredHandler.value?(event)

    // Assert
    #expect(handled == false)
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

    // Test
    let handled = await registeredHandler.value?(event)

    // Assert
    #expect(handled == false)
    _ = sut // Keep reference
  }

}
