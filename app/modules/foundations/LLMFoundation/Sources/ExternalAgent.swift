// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ExternalAgent

/// An external agent is an agent that `cmd` can run and that will autonomously manage its tool calling (e.g Claude Code).
public struct ExternalAgent: Sendable {
  /// The name of the agent.
  public let name: String
  /// The name that we expect the executable to have.
  public let defaultExecutableName: String
  /// A link to instructions on how to install the agent.
  public let installationInstructions: URL
  /// Additional information about this agent's provider.
  public let llmProvider: AIProvider
}

extension AIProvider {
  /// When the LLM provider is an external agent, ie an agent that can use tools when reponding to a prompt,
  /// this value describes properties related to how to use it.
  public var externalAgent: ExternalAgent? {
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

  public var isExternalAgent: Bool {
    externalAgent != nil
  }
}
