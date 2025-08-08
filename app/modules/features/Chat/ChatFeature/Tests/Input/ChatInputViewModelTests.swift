// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation
import Dependencies
import FileSuggestionServiceInterface
import Foundation
import FoundationInterfaces
import LLMFoundation
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
    let selectedModel = LLMModel.gpt
    let activeModels = [LLMModel.claudeSonnet, LLMModel.gpt]
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
    let selectedModel = LLMModel.claudeOpus
    let activeModels = [LLMModel.claudeSonnet, LLMModel.gpt]
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
    let activeModels = [LLMModel.claudeSonnet, LLMModel.gpt]
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
        .anthropic: LLMProviderSettings(
          apiKey: "",
          baseUrl: nil,
          executable: nil,
          createdOrder: 1),
        .openAI: LLMProviderSettings(
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
        activeModels: [.claudeSonnet, .gpt, .gpt_mini])
    }

    #expect(viewModel.selectedModel == .gpt)
  }

  @MainActor
  @Test("updating available models changes selected model if it's no longer available")
  func test_updatingAvailableModels_changesSelectedModelIfNoLongerAvailable() {
    let mockSettingsService = MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      llmProviderSettings: [
        .anthropic: LLMProviderSettings(
          apiKey: "",
          baseUrl: nil,
          executable: nil,
          createdOrder: 1),
        .openAI: LLMProviderSettings(
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
        selectedModel: .claudeSonnet,
        activeModels: nil)
    }

    #expect(viewModel.selectedModel == .claudeSonnet)

    var newSettings = mockSettingsService.value(for: \.llmProviderSettings)
    newSettings[.anthropic] = nil
    mockSettingsService.update(setting: \.llmProviderSettings, to: newSettings)

    #expect(viewModel.selectedModel == .gpt)
  }

  @MainActor
  @Test("updating available models to empty array sets selected model to nil")
  func test_updatingAvailableModels_toEmptyArray() {
    let mockSettingsService = MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      llmProviderSettings: [
        .anthropic: LLMProviderSettings(
          apiKey: "",
          baseUrl: nil,
          executable: nil,
          createdOrder: 1),
        .openAI: LLMProviderSettings(
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
        selectedModel: .claudeSonnet,
        activeModels: nil)
    }

    #expect(viewModel.selectedModel == .claudeSonnet)

    var newSettings = mockSettingsService.value(for: \.llmProviderSettings)
    newSettings[.openAI] = nil
    mockSettingsService.update(setting: \.llmProviderSettings, to: newSettings)

    #expect(viewModel.activeModels.sorted(by: { $0.id < $1.id }) == [
      .claudeHaiku_3_5,
      .claudeOpus,
      .claudeSonnet,
    ])
    #expect(viewModel.selectedModel == .claudeSonnet)

    newSettings[.anthropic] = nil
    mockSettingsService.update(setting: \.llmProviderSettings, to: newSettings)

    #expect(viewModel.activeModels.isEmpty)
    #expect(viewModel.selectedModel == nil)
  }
}

extension MockSettingsService {
  static var allConfigured: MockSettingsService {
    MockSettingsService(Settings(
      pointReleaseXcodeExtensionToDebugApp: false,
      llmProviderSettings: [
        .anthropic: LLMProviderSettings(
          apiKey: "test",
          baseUrl: nil,
          executable: nil,
          createdOrder: 1),
        .openAI: LLMProviderSettings(
          apiKey: "test",
          baseUrl: nil,
          executable: nil,
          createdOrder: 2),
      ]))
  }
}
