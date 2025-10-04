// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation

extension AIProvider {

  public static let groq = AIProvider(
    id: "groq",
    name: "Groq",
    keychainKey: "GROQ_API_KEY",
    websiteURL: URL(string: "https://groq.com/"),
    apiKeyCreationURL: URL(string: "https://console.groq.com/keys"),
    lowTierModelId: "openai/gpt-oss-120b",
    modelsEnabledByDefault: [
      "moonshotai/kimi-k2-instruct-0905",
      "openai/gpt-oss-120b",
    ])
}
