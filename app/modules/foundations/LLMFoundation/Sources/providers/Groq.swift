// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation

extension LLMProvider {

  public static let groq = LLMProvider(
    id: "groq",
    name: "Groq",
    keychainKey: "GROQ_API_KEY",
    supportedModels: [
      .qwen3_32b,
      .gpt_oss_120b,
      .gpt_oss_20b,
      .llama_4_maverick_17b,
    ],
    websiteURL: URL(string: "https://groq.com/"),
    apiKeyCreationURL: URL(string: "https://console.groq.com/keys"),
    idForModel: { model in
      switch model {
      case .qwen3_32b: return "qwen/qwen3-32b"
      case .gpt_oss_120b: return "openai/gpt-oss-120b"
      case .gpt_oss_20b: return "openai/gpt-oss-20b"
      case .llama_4_maverick_17b: return "meta-llama/llama-4-maverick-17b-128e-instruct"
      default: throw AppError(message: "Model \(model) is not supported by Groq provider.")
      }
    },
    priceForModel: { model in
      model.defaultPricing
    })
}
