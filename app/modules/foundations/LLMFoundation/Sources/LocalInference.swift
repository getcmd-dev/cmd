// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - LocalInference

/// Inference with local LLMs (e.g Ollama).
public struct LocalInference: Sendable {
  /// The name of the inference.
  public let name: String
  /// An executable name
  public let executableName: String
  /// A base URL for a local AP..
  public let defaultBaseUrl: URL
  /// A link to instructions on how to install.
  public let installationInstructions: URL
  /// Additional information about the associated provider.
  public let llmProvider: AIProvider
}

extension AIProvider {
  public var localInference: LocalInference? {
    switch self {
    case .ollama:
      .init(
        name: "Ollama",
        executableName: "ollama",
        defaultBaseUrl: URL(string: "http://localhost:11434")!,
        installationInstructions: URL(string: "https://docs.ollama.com/quickstart")!,
        llmProvider: self)

    default:
      nil
    }
  }

  public var isLocalInference: Bool {
    localInference != nil
  }
}
