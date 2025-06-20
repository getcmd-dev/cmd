// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

// MARK: - APIProvider

// enum APIProvider: String, CaseIterable {
//  case anthropic = "Anthropic"
//  case openAI = "OpenAI"
//  case openRouter = "OpenRouter"
// }
//
//// MARK: - ProviderSettings
//
// enum ProviderSettings {
//  case anthropic(AnthropicProviderSettings)
//  case openAI(OpenAIProviderSettings)
//  case openRouter(OpenRouterProviderSettings)
//
//  var provider: APIProvider {
//    switch self {
//    case .anthropic:
//      .anthropic
//    case .openAI:
//      .openAI
//    case .openRouter:
//      .openRouter
//    }
//  }
// }
//
//// MARK: - AnthropicProviderSettings
//
// struct AnthropicProviderSettings {
//  var apiKey: String
//  var baseUrl: String?
// }
//
//// MARK: - OpenAIProviderSettings
//
// struct OpenAIProviderSettings {
//  var apiKey: String
// }
//
//// MARK: - OpenRouterProviderSettings
//
// struct OpenRouterProviderSettings {
//  var apiKey: String
// }
