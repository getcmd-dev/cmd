// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation

extension LLMProvider {

  public static let openRouter = LLMProvider(
    id: "openrouter",
    name: "OpenRouter",
    keychainKey: "OPENROUTER_API_KEY",
    websiteURL: URL(string: "https://openrouter.ai"),
    apiKeyCreationURL: URL(string: "https://openrouter.ai/keys"),
  )
}
