// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - LLMReasoning

public struct LLMReasoning: Sendable, Hashable { }

// MARK: - LLMModel

/// An LLM model.
/// Each model might be provided by differetent providers. For instance both Anthropic and OpenRouter can provide Claude models.
public struct LLMModel: Hashable, Identifiable, CaseIterable, Sendable, RawRepresentable {
  public init?(rawValue: String) {
    if let model = Self.allCases.first(where: { $0.id == rawValue }) {
      self = model
    } else {
      return nil
    }
  }

  init(
    name: String,
    id: String,
    description: String? = nil,
    contextSize: Int,
    maxOutputTokens: Int,
    defaultPricing: ModelPricing,
    documentationURL: URL? = nil,
    reasoning: LLMReasoning? = nil)
  {
    self.id = id
    self.name = name
    self.description = description
    self.contextSize = contextSize
    self.maxOutputTokens = maxOutputTokens
    self.defaultPricing = defaultPricing
    self.documentationURL = documentationURL
    self.reasoning = reasoning
  }

  /// Anthropic
  public static let claudeHaiku_3_5 = LLMModel(
    name: "claude-3.5-haiku",
    id: "claude-haiku-35",
    contextSize: 200_000,
    maxOutputTokens: 8_192,
    defaultPricing: .init(input: 0.8, output: 4, cacheWriteMult: 0.25, cachedInputMult: 0.1),
    documentationURL: URL(string: "https://www.anthropic.com/pricing#api"))
  public static let claudeSonnet = LLMModel(
    name: "claude-4-sonnet",
    id: "claude-sonnet-4",
    contextSize: 200_000,
    maxOutputTokens: 64_000,
    defaultPricing: .init(input: 3, output: 15, cacheWriteMult: 0.25, cachedInputMult: 0.1, inputImage: 4.8),
    documentationURL: URL(string: "https://www.anthropic.com/pricing#api"),
    reasoning: LLMReasoning())
  public static let claudeOpus = LLMModel(
    name: "claude-4.1-opus",
    id: "claude-opus-4",
    contextSize: 200_000,
    maxOutputTokens: 32_000,
    defaultPricing: .init(input: 15, output: 75, cacheWriteMult: 0.25, cachedInputMult: 0.1, inputImage: 24),
    documentationURL: URL(string: "https://www.anthropic.com/pricing#api"),
    reasoning: LLMReasoning())

  public static let claudeCode_default = LLMModel(
    name: "Claude Code",
    id: "claude_code_default",
    contextSize: 200_000,
    maxOutputTokens: 128_000,
    defaultPricing: .init(input: 3, output: 15, cacheWriteMult: 0.25, cachedInputMult: 0.1, inputImage: 4.8),
    documentationURL: URL(string: "https://www.anthropic.com/pricing#api"),
    reasoning: LLMReasoning())

  /// OpenAI
  public static let gpt = LLMModel(
    name: "gpt-5",
    id: "gpt-latest",
    contextSize: 400_000,
    maxOutputTokens: 128_000,
    defaultPricing: .init(input: 1.25, output: 10, cacheWrite: 0, cachedInput: 0.125, inputImage: 1.25),
    documentationURL: URL(string: "https://platform.openai.com/docs/models/gpt-5"),
    reasoning: LLMReasoning())
  public static let gpt_mini = LLMModel(
    name: "gpt-5-mini",
    id: "gpt-mini-latest",
    contextSize: 400_000,
    maxOutputTokens: 128_000,
    defaultPricing: .init(input: 0.25, output: 2, cacheWrite: 0, cachedInput: 0.025, inputImage: 0.25),
    documentationURL: URL(string: "https://platform.openai.com/docs/models/gpt-5-mini"),
    reasoning: LLMReasoning())
  public static let gpt_nano = LLMModel(
    name: "gpt-5-nano",
    id: "gpt-nano-latest",
    contextSize: 400_000,
    maxOutputTokens: 128_000,
    defaultPricing: .init(input: 0.05, output: 0.4, cacheWrite: 0, cachedInput: 0.005, inputImage: 0.05),
    documentationURL: URL(string: "https://platform.openai.com/docs/models/gpt-5-nano"),
    reasoning: LLMReasoning())

  public static var allCases: [LLMModel] {
    // Keep them ordered by most likely to be a good default.
    [
      .claudeSonnet,
      .claudeOpus,
      .claudeCode_default,
      .gpt,
      .claudeHaiku_3_5,
      .gpt_mini,
      .gpt_nano,
    ]
  }

  public let name: String
  public let id: String
  public let description: String?
  public let contextSize: Int
  public let maxOutputTokens: Int
  public let defaultPricing: ModelPricing
  public let documentationURL: URL?
  public let reasoning: LLMReasoning?

  public var rawValue: String {
    id
  }

  /// Whether this model supports reasoning.
  public var canReason: Bool {
    reasoning != nil
  }

  public static func ==(lhs: LLMModel, rhs: LLMModel) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

}
