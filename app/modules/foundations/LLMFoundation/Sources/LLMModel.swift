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
    defaultPricing: ModelPricing,
    documentationURL: URL? = nil,
    reasoning: LLMReasoning? = nil)
  {
    self.id = id
    self.name = name
    self.description = description
    self.contextSize = contextSize
    self.defaultPricing = defaultPricing
    self.documentationURL = documentationURL
    self.reasoning = reasoning
  }

  /// Anthropic
  public static let claudeHaiku_3_5 = LLMModel(
    name: "claude-3.5-haiku",
    id: "claude-haiku-35",
    contextSize: 200_000,
    defaultPricing: .init(input: 0.8, output: 4, cacheWriteMult: 0.25, cachedInputMult: 0.1),
    documentationURL: URL(string: "https://www.anthropic.com/pricing#api"))
  public static let claudeSonnet_3_7 = LLMModel(
    name: "claude-3.7-sonnet",
    id: "claude-sonnet-37",
    contextSize: 200_000,
    defaultPricing: .init(input: 3, output: 15, cacheWriteMult: 0.25, cachedInputMult: 0.1, inputImage: 4.8),
    documentationURL: URL(string: "https://www.anthropic.com/pricing#api"),
    reasoning: LLMReasoning())
  public static let claudeSonnet_4_0 = LLMModel(
    name: "claude-4-sonnet",
    id: "claude-sonnet-4",
    contextSize: 200_000,
    defaultPricing: .init(input: 3, output: 15, cacheWriteMult: 0.25, cachedInputMult: 0.1, inputImage: 4.8),
    documentationURL: URL(string: "https://www.anthropic.com/pricing#api"),
    reasoning: LLMReasoning())
  public static let claudeOpus_4 = LLMModel(
    name: "claude-4-opus",
    id: "claude-opus-4",
    contextSize: 200_000,
    defaultPricing: .init(input: 15, output: 75, cacheWriteMult: 0.25, cachedInputMult: 0.1, inputImage: 24),
    documentationURL: URL(string: "https://www.anthropic.com/pricing#api"),
    reasoning: LLMReasoning())

  /// OpenAI
  public static let gpt_4_1 = LLMModel(
    name: "gpt-4.1",
    id: "gpt-4.1",
    contextSize: 1_047_576,
    defaultPricing: .init(input: 2, output: 8, cacheWrite: 0, cachedInput: 0.5, inputImage: 2),
    documentationURL: URL(string: "https://platform.openai.com/docs/models/gpt-4.1"))
  public static let gpt_4o = LLMModel(
    name: "gpt-4o",
    id: "gpt-4o",
    contextSize: 1_047_576,
    defaultPricing: .init(input: 2.5, output: 10, cacheWrite: 0, cachedInput: 1.25, inputImage: 2.5),
    documentationURL: URL(string: "https://platform.openai.com/docs/models/gpt-4o"))
  public static let o3 = LLMModel(
    name: "o3",
    id: "o3",
    contextSize: 200_000,
    defaultPricing: .init(input: 2, output: 8, cacheWrite: 0, cachedInput: 0.5, inputImage: 1.53),
    documentationURL: URL(string: "https://platform.openai.com/docs/models/o3"),
    reasoning: LLMReasoning())
  public static let o4_mini = LLMModel(
    name: "o4-mini",
    id: "o4-mini",
    contextSize: 200_000,
    defaultPricing: .init(input: 0.4, output: 1.6, cacheWrite: 0, cachedInput: 0.1, inputImage: 1.1),
    documentationURL: URL(string: "https://platform.openai.com/docs/models/o4-mini"),
    reasoning: LLMReasoning())

  public static var allCases: [LLMModel] {
    // Keep them ordered by most likely to be a good default.
    [
      .claudeSonnet_4_0,
      .claudeSonnet_3_7,
      .claudeOpus_4,
      .gpt_4_1,
      .gpt_4o,
      .claudeHaiku_3_5,
      .o3,
      .o4_mini,
    ]
  }

  public let name: String
  public let id: String
  public let description: String?
  public let contextSize: Int
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
