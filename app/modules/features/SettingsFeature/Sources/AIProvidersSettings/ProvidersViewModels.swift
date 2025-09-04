// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation
import LLMFoundation

// MARK: - ExternalAgent

/// An external agent is an agent that `cmd` can run and that will autonomously manage its tool calling (e.g Claude Code).
struct ExternalAgent: Sendable {
  /// The name of the agent.
  let name: String
  /// The name that we expect the executable to have.
  let defaultExecutableName: String
  /// A link to instructions on how to install the agent.
  let installationInstructions: URL
  /// Additional information about this agent's provider.
  let llmProvider: LLMProvider
}

extension LLMProvider {
  /// When the LLM provider is an external agent, ie an agent that can use tools when reponding to a prompt,
  /// this value describes properties related to how to use it.
  var externalAgent: ExternalAgent? {
    switch self {
    case .claudeCode:
      .init(
        name: "Claude Code",
        defaultExecutableName: "claude",
        installationInstructions: URL(string: "https://docs.anthropic.com/en/docs/claude-code/setup#standard-installation")!,
        llmProvider: self)

    default:
      nil
    }
  }
}
