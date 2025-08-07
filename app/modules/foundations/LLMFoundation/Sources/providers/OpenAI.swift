// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation

extension LLMProvider {

  public static let openAI = LLMProvider(
    id: "openai",
    name: "OpenAI",
    keychainKey: "OPENAI_API_KEY",
    supportedModels: [
      .gpt,
      .gpt_mini,
      .gpt_nano,
    ],
    idForModel: { model in
      switch model {
      case .gpt: return "gpt-5"
      case .gpt_mini: return "gpt-5-mini"
      case .gpt_nano: return "gpt-5-nano"
      default: throw AppError(message: "Model \(model) is not supported by Anthropic provider.")
      }
    },
    priceForModel: { model in
      model.defaultPricing
    })
}
