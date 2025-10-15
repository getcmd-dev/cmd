// swiftformat:disable all
// This file is generated from ./local-server/src/server/schemas/listModelsSchema.ts by `yarn export-schema-swift`.
// Do not edit it manually.

import Foundation
import JSONFoundation

extension Schema {
  public struct ListModelsInput: Codable, Sendable {
    public let provider: APIProvider
  
    private enum CodingKeys: String, CodingKey {
      case provider = "provider"
    }
  
    public init(
        provider: APIProvider
    ) {
      self.provider = provider
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      provider = try container.decode(APIProvider.self, forKey: .provider)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(provider, forKey: .provider)
    }
  }
  public struct ListModelsOutput: Codable, Sendable {
    public let models: [Model]
  
    private enum CodingKeys: String, CodingKey {
      case models = "models"
    }
  
    public init(
        models: [Model]
    ) {
      self.models = models
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      models = try container.decode([Model].self, forKey: .models)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(models, forKey: .models)
    }
  }
  public struct Model: Codable, Sendable {
    public let providerId: String
    public let globalId: String
    public let name: String
    public let description: String
    public let contextLength: Int
    public let maxCompletionTokens: Int
    public let inputModalities: [ModelModality]
    public let outputModalities: [ModelModality]
    public let pricing: ModelPricing
    public let createdAt: Double
    public let rankForProgramming: Int
  
    private enum CodingKeys: String, CodingKey {
      case providerId = "providerId"
      case globalId = "globalId"
      case name = "name"
      case description = "description"
      case contextLength = "contextLength"
      case maxCompletionTokens = "maxCompletionTokens"
      case inputModalities = "inputModalities"
      case outputModalities = "outputModalities"
      case pricing = "pricing"
      case createdAt = "createdAt"
      case rankForProgramming = "rankForProgramming"
    }
  
    public init(
        providerId: String,
        globalId: String,
        name: String,
        description: String,
        contextLength: Int,
        maxCompletionTokens: Int,
        inputModalities: [ModelModality],
        outputModalities: [ModelModality],
        pricing: ModelPricing,
        createdAt: Double,
        rankForProgramming: Int
    ) {
      self.providerId = providerId
      self.globalId = globalId
      self.name = name
      self.description = description
      self.contextLength = contextLength
      self.maxCompletionTokens = maxCompletionTokens
      self.inputModalities = inputModalities
      self.outputModalities = outputModalities
      self.pricing = pricing
      self.createdAt = createdAt
      self.rankForProgramming = rankForProgramming
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      providerId = try container.decode(String.self, forKey: .providerId)
      globalId = try container.decode(String.self, forKey: .globalId)
      name = try container.decode(String.self, forKey: .name)
      description = try container.decode(String.self, forKey: .description)
      contextLength = try container.decode(Int.self, forKey: .contextLength)
      maxCompletionTokens = try container.decode(Int.self, forKey: .maxCompletionTokens)
      inputModalities = try container.decode([ModelModality].self, forKey: .inputModalities)
      outputModalities = try container.decode([ModelModality].self, forKey: .outputModalities)
      pricing = try container.decode(ModelPricing.self, forKey: .pricing)
      createdAt = try container.decode(Double.self, forKey: .createdAt)
      rankForProgramming = try container.decode(Int.self, forKey: .rankForProgramming)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(providerId, forKey: .providerId)
      try container.encode(globalId, forKey: .globalId)
      try container.encode(name, forKey: .name)
      try container.encode(description, forKey: .description)
      try container.encode(contextLength, forKey: .contextLength)
      try container.encode(maxCompletionTokens, forKey: .maxCompletionTokens)
      try container.encode(inputModalities, forKey: .inputModalities)
      try container.encode(outputModalities, forKey: .outputModalities)
      try container.encode(pricing, forKey: .pricing)
      try container.encode(createdAt, forKey: .createdAt)
      try container.encode(rankForProgramming, forKey: .rankForProgramming)
    }
  }
  public enum ModelModality: String, Codable, Sendable {
    case text = "text"
    case image = "image"
    case file = "file"
    case audio = "audio"
  }    
  public struct ModelPricing: Codable, Sendable {
    public let prompt: Double
    public let completion: Double
    public let image: Double?
    public let request: Double?
    public let webSearch: Double?
    public let internalReasoning: Double?
    public let inputCacheRead: Double?
    public let inputCacheWrite: Double?
  
    private enum CodingKeys: String, CodingKey {
      case prompt = "prompt"
      case completion = "completion"
      case image = "image"
      case request = "request"
      case webSearch = "web_search"
      case internalReasoning = "internal_reasoning"
      case inputCacheRead = "input_cache_read"
      case inputCacheWrite = "input_cache_write"
    }
  
    public init(
        prompt: Double,
        completion: Double,
        image: Double? = nil,
        request: Double? = nil,
        webSearch: Double? = nil,
        internalReasoning: Double? = nil,
        inputCacheRead: Double? = nil,
        inputCacheWrite: Double? = nil
    ) {
      self.prompt = prompt
      self.completion = completion
      self.image = image
      self.request = request
      self.webSearch = webSearch
      self.internalReasoning = internalReasoning
      self.inputCacheRead = inputCacheRead
      self.inputCacheWrite = inputCacheWrite
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      prompt = try container.decode(Double.self, forKey: .prompt)
      completion = try container.decode(Double.self, forKey: .completion)
      image = try container.decodeIfPresent(Double?.self, forKey: .image)
      request = try container.decodeIfPresent(Double?.self, forKey: .request)
      webSearch = try container.decodeIfPresent(Double?.self, forKey: .webSearch)
      internalReasoning = try container.decodeIfPresent(Double?.self, forKey: .internalReasoning)
      inputCacheRead = try container.decodeIfPresent(Double?.self, forKey: .inputCacheRead)
      inputCacheWrite = try container.decodeIfPresent(Double?.self, forKey: .inputCacheWrite)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(prompt, forKey: .prompt)
      try container.encode(completion, forKey: .completion)
      try container.encodeIfPresent(image, forKey: .image)
      try container.encodeIfPresent(request, forKey: .request)
      try container.encodeIfPresent(webSearch, forKey: .webSearch)
      try container.encodeIfPresent(internalReasoning, forKey: .internalReasoning)
      try container.encodeIfPresent(inputCacheRead, forKey: .inputCacheRead)
      try container.encodeIfPresent(inputCacheWrite, forKey: .inputCacheWrite)
    }
  }}
