// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation
import Dependencies
import FileSuggestionServiceInterface
import Foundation
import FoundationInterfaces
import LLMFoundation
import LLMServiceInterface
import SettingsServiceInterface
import SwiftTesting
import Testing
import XcodeObserverServiceInterface
@testable import ChatFeature

// MARK: - ChatInputViewModelTests

struct ChatInputViewModelTests {

  @MainActor
  @Test("initializing with a selected model that is in available models keeps that model")
  func test_initialization_withSelectedModelInAvailableModels() {
    let selectedModel = AIModel.gpt
    let activeModels: [AIModel] = [.claudeSonnet, .gpt]
    let mockSettingsService = MockSettingsService.allConfigured

    let viewModel = withDependencies {
      $0.settingsService = mockSettingsService
    } operation: {
      ChatInputViewModel(
        selectedModel: selectedModel,
        activeModels: activeModels)
    }

    #expect(viewModel.selectedModel == selectedModel)
    #expect(viewModel.activeModels == activeModels)
  }

  @MainActor
  @Test("initializing with a selected model that is not in available models selects the first available model")
  func test_initialization_withSelectedModelNotInAvailableModels() {
    let selectedModel = AIModel.claudeOpus
    let activeModels: [AIModel] = [.claudeSonnet, .gpt]
    let mockSettingsService = MockSettingsService.allConfigured

    let viewModel = withDependencies {
      $0.settingsService = mockSettingsService
    } operation: {
      ChatInputViewModel(
        selectedModel: selectedModel,
        activeModels: activeModels)
    }

    #expect(viewModel.selectedModel == activeModels.first)
    #expect(viewModel.activeModels == activeModels)
  }

  @MainActor
  @Test("initializing with nil selected model selects the first available model")
  func test_initialization_withNilSelectedModel() {
    let activeModels: [AIModel] = [.claudeSonnet, .gpt]
    let mockSettingsService = MockSettingsService.allConfigured

    let viewModel = withDependencies {
      $0.settingsService = mockSettingsService
    } operation: {
      ChatInputViewModel(
        selectedModel: nil,
        activeModels: activeModels)
    }

    #expect(viewModel.selectedModel == activeModels.first)
    #expect(viewModel.activeModels == activeModels)
  }

  @MainActor
  @Test("initializing with empty available models results in nil selected model")
  func test_initialization_withEmptyAvailableModels() {
    let mockSettingsService = MockSettingsService.allConfigured

    let viewModel = withDependencies {
      $0.settingsService = mockSettingsService
    } operation: {
      ChatInputViewModel(
        selectedModel: nil,
        activeModels: [])
    }

    #expect(viewModel.selectedModel == nil)
  }

  @MainActor
  @Test("updating available models keeps selected model if it's still available")
  func test_updatingAvailableModels_keepsSelectedModelIfStillAvailable() {
    let mockSettingsService = MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      llmProviderSettings: [
        .anthropic: AIProviderSettings(
          apiKey: "",
          baseUrl: nil,
          executable: nil,
          createdOrder: 1),
        .openAI: AIProviderSettings(
          apiKey: "",
          baseUrl: nil,
          executable: nil,
          createdOrder: 2),
      ]))
    let mockUserDefaults = MockUserDefaults()

    let viewModel = withDependencies {
      $0.settingsService = mockSettingsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      ChatInputViewModel(
        selectedModel: .gpt,
        activeModels: [.claudeSonnet, .gpt, .gpt_turbo])
    }

    #expect(viewModel.selectedModel == .gpt)
  }

  @MainActor
  @Test("updating available models changes selected model if it's no longer available")
  func test_updatingAvailableModels_changesSelectedModelIfNoLongerAvailable() async throws {
    // given
    let mockLLMService = MockLLMService(activeModels: [.claudeSonnet, .gpt])
    let mockSettingsService = MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      llmProviderSettings: [
        .anthropic: AIProviderSettings(
          apiKey: "",
          baseUrl: nil,
          executable: nil,
          createdOrder: 1),
        .openAI: AIProviderSettings(
          apiKey: "",
          baseUrl: nil,
          executable: nil,
          createdOrder: 2),
      ]))
    let mockUserDefaults = MockUserDefaults()

    let sut = withDependencies {
      $0.llmService = mockLLMService
      $0.settingsService = mockSettingsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      ChatInputViewModel(
        selectedModel: .claudeSonnet,
        activeModels: nil)
    }
    let hasChangedModelToGpt = expectation(description: "Has changed model to gpt")
    let cancellable = sut.observeChanges(to: \.selectedModel) { newValue in
      if newValue == .gpt {
        hasChangedModelToGpt.fulfillAtMostOnce()
      }
    }
    #expect(sut.selectedModel == .claudeSonnet)

    // when
    mockLLMService._activeModels.send([.gpt])

    // then
    try await fulfillment(of: hasChangedModelToGpt)
    _ = cancellable

    // then
    #expect(sut.selectedModel == .gpt)
  }

  @MainActor
  @Test("updating available models to empty array sets selected model to nil")
  func test_updatingAvailableModels_toEmptyArray() async throws {
    // given
    let mockLLMService = MockLLMService(activeModels: [.claudeSonnet])
    let mockSettingsService = MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      llmProviderSettings: [
        .anthropic: AIProviderSettings(
          apiKey: "",
          baseUrl: nil,
          executable: nil,
          createdOrder: 1),
        .openAI: AIProviderSettings(
          apiKey: "",
          baseUrl: nil,
          executable: nil,
          createdOrder: 2),
      ]))
    let mockUserDefaults = MockUserDefaults()

    let sut = withDependencies {
      $0.llmService = mockLLMService
      $0.settingsService = mockSettingsService
      $0.userDefaults = mockUserDefaults
    } operation: {
      ChatInputViewModel(
        selectedModel: .claudeSonnet,
        activeModels: nil)
    }
    #expect(sut.selectedModel == .claudeSonnet)

    // Prepare observation to changes in propeerties
    let hasChangedActiveModels = expectation(description: "Has changed active models")
    let hasChangedSelectedModels = expectation(description: "Has changed selected model")
    var cancellables = Set<AnyCancellable>()
    sut.observeChanges(to: \.activeModels) { _ in
      hasChangedActiveModels.fulfillAtMostOnce()
    }.store(in: &cancellables)
    sut.observeChanges(to: \.selectedModel) { _ in
      hasChangedSelectedModels.fulfillAtMostOnce()
    }.store(in: &cancellables)

    // when - simulate removing openAI provider (anthropic models remain)
    mockLLMService._activeModels.send([
      .claudeHaiku_3_5,
      .claudeOpus,
      .claudeSonnet,
    ])

    // then
    try await fulfillment(of: hasChangedActiveModels)
    #expect(sut.activeModels.sorted(by: { $0.id < $1.id }) == [
      .claudeHaiku_3_5,
      .claudeOpus,
      .claudeSonnet,
    ])
    #expect(sut.selectedModel == .claudeSonnet)

    // when - simulate removing all providers
    mockLLMService._activeModels.send([])
    try await fulfillment(of: hasChangedSelectedModels)

    // then
    #expect(sut.activeModels.isEmpty)
    #expect(sut.selectedModel == nil)
    _ = cancellables
  }
}

extension MockSettingsService {
  static var allConfigured: MockSettingsService {
    MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      llmProviderSettings: [
        .anthropic: AIProviderSettings(
          apiKey: "test",
          baseUrl: nil,
          executable: nil,
          createdOrder: 1),
        .openAI: AIProviderSettings(
          apiKey: "test",
          baseUrl: nil,
          executable: nil,
          createdOrder: 2),
      ]))
  }
}
