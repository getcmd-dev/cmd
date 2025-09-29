// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation

extension LLMProvider {

  public static let openRouter = LLMProvider(
    id: "openrouter",
    name: "OpenRouter",
    keychainKey: "OPENROUTER_API_KEY",
    supportedModels: [
      .claudeHaiku_3_5,
      .claudeSonnet,
      .claudeOpus,
      .gpt,
      .gpt_mini,
      .gpt_nano,
    ],
    websiteURL: URL(string: "https://openrouter.ai"),
    apiKeyCreationURL: URL(string: "https://openrouter.ai/keys"),
    idForModel: { model in
      switch model {
      case .claudeHaiku_3_5: return "anthropic/claude-3.5-haiku"
      case .claudeSonnet: return "anthropic/claude-sonnet-4.5"
      case .claudeOpus: return "anthropic/claude-opus-4.1"
      case .gpt: return "openai/gpt-5"
      case .gpt_mini: return "openai/gpt-5-mini"
      case .gpt_nano: return "openai/gpt-5-nano"
      default: throw AppError(message: "Model \(model) is not supported by Anthropic provider.")
      }
    },
    priceForModel: { model in
      model.defaultPricing
    })
}
