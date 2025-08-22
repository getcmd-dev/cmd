// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation

extension LLMProvider {

  public static let claudeCode = LLMProvider(
    id: "claudeCode",
    name: "Claude Code",
    keychainKey: "CLAUDE_CODE_PATH",
    supportedModels: [
      .claudeCode_default,
    ],
    websiteURL: URL(string: "https://www.anthropic.com/claude-code"),
    idForModel: { model in
      switch model {
      case .claudeCode_default: return ""
      default: throw AppError(message: "Model \(model) is not supported by Claude Code provider.")
      }
    },
    priceForModel: { model in
      model.defaultPricing
    })
}
