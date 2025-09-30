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
    defaultPricing: ModelPricing?,
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
    name: "claude-4.5-sonnet",
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
    defaultPricing: nil,
    documentationURL: URL(string: "https://www.anthropic.com/pricing#api"))

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

  /// Groq
  public static let qwen3_32b = LLMModel(
    name: "qwen3-32b",
    id: "qwen3-32b",
    contextSize: 131_072,
    maxOutputTokens: 40_960,
    defaultPricing: .init(input: 0.29, output: 0.59, cacheWriteMult: 0, cachedInputMult: 0.5),
    documentationURL: URL(string: "https://huggingface.co/Qwen/Qwen3-32B"),
    reasoning: LLMReasoning())
  public static let gpt_oss_120b = LLMModel(
    name: "gpt-oss-120b",
    id: "gpt-oss-120b",
    contextSize: 131_072,
    maxOutputTokens: 65_536,
    defaultPricing: .init(input: 0.15, output: 0.75, cacheWriteMult: 0, cachedInputMult: 0.5),
    documentationURL: URL(string: "https://console.groq.com/docs/model/openai/gpt-oss-120b"),
    reasoning: LLMReasoning())
  public static let gpt_oss_20b = LLMModel(
    name: "gpt-oss-20b",
    id: "gpt-oss-20b",
    contextSize: 131_072,
    maxOutputTokens: 65_536,
    defaultPricing: .init(input: 0.10, output: 0.50, cacheWriteMult: 0, cachedInputMult: 0.5),
    documentationURL: URL(string: "https://console.groq.com/docs/model/openai/gpt-oss-20b"),
    reasoning: LLMReasoning())
  public static let llama_4_maverick_17b = LLMModel(
    name: "Llama 4 Maverick",
    id: "llama-4-maverick-17b",
    contextSize: 131_072,
    maxOutputTokens: 8_192,
    defaultPricing: .init(input: 0.20, output: 0.60, cacheWriteMult: 0, cachedInputMult: 0.5),
    documentationURL: URL(string: "https://huggingface.co/meta-llama/Llama-4-Maverick-17B-128E-Instruct"))
  public static let kimi_k2 = LLMModel(
    name: "Kimi K2",
    id: "kimi-k2",
    contextSize: 131_072,
    maxOutputTokens: 16_384,
    defaultPricing: .init(input: 1, output: 3, cacheWriteMult: 0, cachedInputMult: 0.5),
    documentationURL: URL(string: "https://huggingface.co/moonshotai/Kimi-K2-Instruct"))

  /// Google Vertex AI
  public static let gemini_2_5_pro = LLMModel(
    name: "Gemini 2.5 Pro",
    id: "gemini-2-5-pro",
    contextSize: 1_048_576,
    maxOutputTokens: 65_535,
    defaultPricing: .init(input: 1.25, output: 10, cacheWriteMult: 0, cachedInputMult: 0),
    documentationURL: URL(string: "https://ai.google.dev/gemini-api/docs/models#gemini-2.5-pro"),
    reasoning: LLMReasoning())
  public static let gemini_2_5_flash = LLMModel(
    name: "Gemini 2.5 Flash",
    id: "gemini-2-5-flash",
    contextSize: 1_048_576,
    maxOutputTokens: 65_535,
    defaultPricing: .init(input: 0.30, output: 2.50, cacheWriteMult: 0, cachedInputMult: 0),
    documentationURL: URL(string: "https://ai.google.dev/gemini-api/docs/models#gemini-2.5-flash"),
    reasoning: LLMReasoning())
  public static let gemini_2_5_flash_lite = LLMModel(
    name: "Gemini 2.5 Flash Lite",
    id: "gemini-2-5-flash-lite",
    contextSize: 1_048_576,
    maxOutputTokens: 65_536,
    defaultPricing: .init(input: 0.10, output: 0.40, cacheWriteMult: 0, cachedInputMult: 0),
    documentationURL: URL(string: "https://ai.google.dev/gemini-api/docs/models#gemini-2.5-flash-lite"),
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
      .gemini_2_5_pro,
      .gemini_2_5_flash,
      .gemini_2_5_flash_lite,
      .qwen3_32b,
      .gpt_oss_120b,
      .gpt_oss_20b,
      .llama_4_maverick_17b,
    ]
  }

  public let name: String
  public let id: String
  public let description: String?
  public let contextSize: Int
  public let maxOutputTokens: Int
  public let defaultPricing: ModelPricing?
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
