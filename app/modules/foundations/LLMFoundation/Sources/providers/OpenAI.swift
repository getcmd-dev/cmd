// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation

extension AIProvider {

  public static let openAI = AIProvider(
    id: "openai",
    name: "OpenAI",
    keychainKey: "OPENAI_API_KEY",
    websiteURL: URL(string: "https://platform.openai.com/docs/models"),
    apiKeyCreationURL: URL(string: "https://platform.openai.com/api-keys"),
    lowTierModelId: "openai/gpt-3.5-turbo",
    modelsEnabledByDefault: [
      "openai/gpt-3.5-turbo",
      "openai/gpt-5",
    ])
}
