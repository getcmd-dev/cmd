// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - LLMReasoning

public struct LLMReasoning: Sendable, Hashable, Codable { }

// MARK: - LLMModel

public struct LLMModel: Hashable, Identifiable, Sendable, Codable {
  public let providerId: String
  public let provider: LLMProvider
  public let modelInfo: LLMModelInfo

  public var id: String {
    providerId
  }

  public init(providerId: String, provider: LLMProvider, modelInfo: LLMModelInfo) {
    self.providerId = providerId
    self.provider = provider
    self.modelInfo = modelInfo
  }
}

// MARK: - LLMModelInfo

/// An LLM model.
/// Each model might be provided by differetent providers. For instance both Anthropic and OpenRouter can provide Claude models.
public struct LLMModelInfo: Hashable, Identifiable, Sendable, Codable {
  public init(
    name: String,
    slug: String,
    description: String? = nil,
    contextSize: Int,
    maxOutputTokens: Int,
    defaultPricing: ModelPricing?, // TODO: Make non-optional when we have pricing for all models.
    documentationURL: URL? = nil,
    reasoning: LLMReasoning? = nil,
    createdAt: TimeInterval,
    rankForProgramming: Int)
  {
    self.slug = slug
    self.name = name
    self.description = description
    self.contextSize = contextSize
    self.maxOutputTokens = maxOutputTokens
    self.defaultPricing = defaultPricing
    self.documentationURL = documentationURL
    self.reasoning = reasoning
    self.createdAt = createdAt
    self.rankForProgramming = rankForProgramming
  }

  /// A few models for debugging and providing default values.
  public static let claudeHaiku_3_5 = LLMModelInfo(
    name: "claude-3.5-haiku",
    slug: "claude-haiku-35",
    contextSize: 200_000,
    maxOutputTokens: 8_192,
    defaultPricing: .init(input: 0.8, output: 4, cacheWriteMult: 0.25, cachedInputMult: 0.1),
    documentationURL: URL(string: "https://www.anthropic.com/pricing#api"),
    createdAt: 1730678400,
    rankForProgramming: 2)
  public static let claudeSonnet = LLMModelInfo(
    name: "claude-4.5-sonnet",
    slug: "claude-sonnet-4",
    contextSize: 200_000,
    maxOutputTokens: 64_000,
    defaultPricing: .init(input: 3, output: 15, cacheWriteMult: 0.25, cachedInputMult: 0.1, inputImage: 4.8),
    documentationURL: URL(string: "https://www.anthropic.com/pricing#api"),
    reasoning: LLMReasoning(),
    createdAt: 1759161676,
    rankForProgramming: 1)

  #if DEBUG
    public static let gpt = LLMModelInfo(
        name: "gpt-5",
        slug: "gpt-latest",
        contextSize: 400_000,
        maxOutputTokens: 128_000,
        defaultPricing: .init(input: 1.25, output: 10, cacheWrite: 0, cachedInput: 0.125, inputImage: 1.25),
        documentationURL: URL(string: "https://platform.openai.com/docs/models/gpt-5"),
        reasoning: LLMReasoning(),
        createdAt: 1759161676,
        rankForProgramming: 3)
    public static let gpt_mini = LLMModelInfo(
        name: "gpt-5-mini",
        slug: "gpt-mini-latest",
        contextSize: 400_000,
        maxOutputTokens: 128_000,
        defaultPricing: .init(input: 0.25, output: 2, cacheWrite: 0, cachedInput: 0.025, inputImage: 0.25),
        documentationURL: URL(string: "https://platform.openai.com/docs/models/gpt-5-mini"),
        reasoning: LLMReasoning(),
        createdAt: 1759161676,
        rankForProgramming: 3)
    public static let claudeOpus = LLMModelInfo(
      name: "claude-4.1-opus",
      slug: "claude-opus-4",
      contextSize: 200_000,
      maxOutputTokens: 32_000,
      defaultPricing: .init(input: 15, output: 75, cacheWriteMult: 0.25, cachedInputMult: 0.1, inputImage: 24),
      documentationURL: URL(string: "https://www.anthropic.com/pricing#api"),
      reasoning: LLMReasoning(),
      createdAt: 1759161676,
      rankForProgramming: 3)
    
  public static let allTestCases: [LLMModelInfo] = [.claudeHaiku_3_5, .claudeSonnet]
  #endif

  public let name: String
  public let slug: String
  public let description: String?
  public let contextSize: Int
  public let maxOutputTokens: Int
  public let defaultPricing: ModelPricing?
  public let documentationURL: URL?
  public let reasoning: LLMReasoning?
  public let createdAt: TimeInterval
  public let rankForProgramming: Int

  public var id: String {
    slug
  }

  public var rawValue: String {
    slug
  }

  /// Whether this model supports reasoning.
  public var canReason: Bool {
    reasoning != nil
  }

  public static func ==(lhs: LLMModelInfo, rhs: LLMModelInfo) -> Bool {
    lhs.slug == rhs.slug
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(slug)
  }

}
