// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation

extension LLMProvider {

  public static let gemini = LLMProvider(
    id: "gemini",
    name: "Google Gemini",
    keychainKey: "GEMINI_API_KEY",
    supportedModels: [
      .gemini_2_5_pro,
      .gemini_2_5_flash,
      .gemini_2_5_flash_lite,
    ],
    websiteURL: URL(string: "https://ai.google.dev/"),
    apiKeyCreationURL: URL(string: "https://aistudio.google.com/app/apikey"),
    idForModel: { model in
      switch model {
      case .gemini_2_5_pro: return "gemini-2.5-pro"
      case .gemini_2_5_flash: return "gemini-2.5-flash"
      case .gemini_2_5_flash_lite: return "gemini-2.5-flash-lite"
      default: throw AppError(message: "Model \(model) is not supported by Gemini provider.")
      }
    },
    priceForModel: { model in
      model.defaultPricing
    })
}
