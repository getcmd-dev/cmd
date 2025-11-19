// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation

extension AIProvider {

  public static let mistral = AIProvider(
    id: "mistral",
    name: "Mistral",
    keychainKey: "MISTRAL_API_KEY",
    websiteURL: URL(string: "https://docs.mistral.ai/getting-started/models#premier-models"),
    apiKeyCreationURL: URL(string: "https://console.mistral.ai/home?workspace_dialog=apiKeys"),
    lowTierModelId: "mistral-small",
    modelsEnabledByDefault: [
      "mistralai/codestral-2508",
    ])
}
