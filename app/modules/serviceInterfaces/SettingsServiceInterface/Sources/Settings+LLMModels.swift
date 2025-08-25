// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import LLMFoundation

extension SettingsServiceInterface.Settings {
  /// The LLM models that have been configured and are available for use.
  public var availableModels: [LLMModel] {
    var models = Set<LLMModel>()
    if llmProviderSettings[.anthropic] != nil {
      for supportedModel in LLMProvider.anthropic.supportedModels { models.insert(supportedModel) }
    }
    if llmProviderSettings[.openAI] != nil {
      for supportedModel in LLMProvider.openAI.supportedModels { models.insert(supportedModel) }
    }
    if llmProviderSettings[.openRouter] != nil {
      for supportedModel in LLMProvider.openRouter.supportedModels { models.insert(supportedModel) }
    }
    if llmProviderSettings[.claudeCode] != nil {
      for supportedModel in LLMProvider.claudeCode.supportedModels { models.insert(supportedModel) }
    }
    if llmProviderSettings[.groq] != nil {
      for supportedModel in LLMProvider.groq.supportedModels { models.insert(supportedModel) }
    }
    if llmProviderSettings[.gemini] != nil {
      for supportedModel in LLMProvider.gemini.supportedModels { models.insert(supportedModel) }
    }
    return LLMModel.allCases.filter { models.contains($0) }
  }

  /// The active models. A model might be available (one of its provider is configured), but inactive as the user doesn't want to use it.
  public var activeModels: [LLMModel] {
    availableModels.filter { !inactiveModels.contains($0) }
  }

  /// A model that can be used for simple queries that favor speed & low cost over accuracy.
  public var lowTierModel: LLMModel? {
    let preferredLowTierModels: [LLMModel] = [
      .claudeHaiku_3_5,
      .gpt_mini,
      .gpt_oss_20b,
    ]
    return availableModels.sorted(by: { a, b in
      let i = preferredLowTierModels.firstIndex(of: a)
      let j = preferredLowTierModels.firstIndex(of: b)

      switch (i, j) {
      case (let i?, let j?): return i < j
      case (_?, nil): return true
      case (nil, _?): return false
      case (nil, nil): return a.defaultPricing.input < b.defaultPricing.input
      }
    }).first
  }

  /// The provider for a given model, and its configuration.
  public func provider(for model: LLMModel) throws -> (LLMProvider, LLMProviderSettings) {
    let preferedProviders = preferedProviders[model]
    let provider = llmProviderSettings
      .filter { $0.key.supportedModels.contains(model) }
      .sorted(by: { a, b in
        if a.key == preferedProviders {
          return true
        } else if b.key == preferedProviders {
          return false
        }
        return a.value.createdOrder < b.value.createdOrder
      })
      .first
    guard let provider else {
      throw AppError(message: "Unsupported model \(model.name)")
    }
    return (provider.key, provider.value)
  }

}
