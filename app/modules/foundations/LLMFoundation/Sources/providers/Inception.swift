// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation

extension AIProvider {

  public static let inception = AIProvider(
    id: "inception",
    name: "Inception",
    keychainKey: "INCEPTION_API_KEY",
    websiteURL: URL(string: "https://www.inceptionlabs.ai/"),
    apiKeyCreationURL: URL(string: "https://platform.inceptionlabs.ai/dashboard/api-keys"),
    lowTierModelId: "inception/mercury",
    modelsEnabledByDefault: [
      "inception/mercury",
      "inception/mercury-coder",
    ])
}
