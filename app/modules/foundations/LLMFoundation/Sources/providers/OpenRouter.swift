// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation

extension AIProvider {

  public static let openRouter = AIProvider(
    id: "openrouter",
    name: "OpenRouter",
    keychainKey: "OPENROUTER_API_KEY",
    websiteURL: URL(string: "https://openrouter.ai"),
    apiKeyCreationURL: URL(string: "https://openrouter.ai/keys"),
    lowTierModelId: "openai/gpt-3.5-turbo",
    modelsEnabledByDefault: [
      "anthropic/claude-opus-4.1",
      "anthropic/claude-sonnet-4.5",
      "google/gemini-2.5-pro",
      "openai/gpt-5",
    ])
}
