// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation

extension LLMProvider {

  public static let openAI = LLMProvider(
    id: "openai",
    name: "OpenAI",
    keychainKey: "OPENAI_API_KEY",
    websiteURL: URL(string: "https://platform.openai.com/docs/models"),
    apiKeyCreationURL: URL(string: "https://platform.openai.com/api-keys"))
}
