// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation

extension AIProvider {

  public static let gemini = AIProvider(
    id: "gemini",
    name: "Google Gemini",
    keychainKey: "GEMINI_API_KEY",
    websiteURL: URL(string: "https://ai.google.dev/"),
    apiKeyCreationURL: URL(string: "https://aistudio.google.com/app/apikey"),
    lowTierModelId: "google/gemini-2.5-flash-lite",
    modelsEnabledByDefault: [
      "google/gemini-2.5-pro",
      "google/gemini-2.5-flash-lite",
    ])
}
