// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation

extension AIProvider {

  public static let claudeCode = AIProvider(
    id: "claudeCode",
    name: "Claude Code",
    keychainKey: "CLAUDE_CODE_PATH",
    websiteURL: URL(string: "https://www.anthropic.com/claude-code"),
    modelsEnabledByDefault: [])
}
