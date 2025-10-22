// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation

extension AIProvider {

  public static let codex = AIProvider(
    id: "codex",
    name: "Codex",
    keychainKey: "CODEX_PATH",
    websiteURL: URL(string: "https://developers.openai.com/codex/cli/"),
    modelsEnabledByDefault: [])
}
