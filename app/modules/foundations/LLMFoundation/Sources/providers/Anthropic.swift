// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation

extension AIProvider {

  public static let anthropic = AIProvider(
    id: "anthropic",
    name: "Anthropic",
    keychainKey: "ANTHROPIC_API_KEY",
    websiteURL: URL(string: "https://www.anthropic.com/claude"),
    apiKeyCreationURL: URL(string: "https://console.anthropic.com/settings/keys"),
    lowTierModelId: "anthropic/claude-3.5-haiku",
    modelsEnabledByDefault: [
      "anthropic/claude-opus-4.1",
      "anthropic/claude-sonnet-4.5",
      "anthropic/claude-3.5-haiku",
    ])
}
