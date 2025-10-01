// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import Foundation
import LLMFoundation
import LocalServerServiceInterface
import LoggingServiceInterface
import SettingsServiceInterface
import SwiftUI

// MARK: - AIProviderViewModel

@Observable
@MainActor
public final class AIProviderViewModel {
  public init(
    provider: LLMProvider,
    settings: LLMProviderSettings,
    saveSettings: @escaping (LLMProviderSettings) -> Void)
  {
    self.provider = provider
    self.settings = settings
    self.saveSettings = saveSettings

    @Dependency(\.localServer) var localServer
    self.localServer = localServer

    // Fetch available models on initialization
    Task {
      await fetchAvailableModels()
    }
  }

  public let provider: LLMProvider
  public var settings: LLMProviderSettings

  private let saveSettings: (LLMProviderSettings) -> Void

  private let localServer: LocalServer

  private func fetchAvailableModels() async {
    do {
      let apiProviderName = convertToAPIProviderName(provider)

      // Create the API provider settings
      let providerSettings = Schema.APIProvider.Settings(
        apiKey: settings.apiKey.isEmpty ? nil : settings.apiKey,
        baseUrl: settings.baseUrl,
        localExecutable: nil)
      let apiProvider = Schema.APIProvider(
        name: apiProviderName,
        settings: providerSettings)
      let input = Schema.ListModelsInput(provider: apiProvider)

      let inputData = try JSONEncoder().encode(input)
      let output: Schema.ListModelsOutput = try await localServer.postRequest(
        path: "/models",
        data: inputData)
      defaultLogger.log("Received \(output.models.count) models for provider \(provider.name)")

    } catch {
      defaultLogger.error("Failed to fetch models for provider \(provider.name)", error)
    }
  }

  private func convertToAPIProviderName(_ provider: LLMProvider) -> Schema.APIProviderName {
    switch provider {
    case .openAI:
      return .openai
    case .anthropic:
      return .anthropic
    case .openRouter:
      return .openrouter
    case .claudeCode:
      return .claudeCode
    case .groq:
      return .groq
    case .gemini:
      return .gemini
    default:
      defaultLogger.error("Provider \(provider.name) is not supported by the local server, defaulting to Anthropic")
      return .anthropic
    }
  }
}
