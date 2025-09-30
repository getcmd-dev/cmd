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
  public struct APIProvider: Codable, Sendable {
    public let name: APIProviderName
    public let settings: Settings
  
    private enum CodingKeys: String, CodingKey {
      case name = "name"
      case settings = "settings"
    }
  
    public init(
        name: APIProviderName,
        settings: Settings
    ) {
      self.name = name
      self.settings = settings
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      name = try container.decode(APIProviderName.self, forKey: .name)
      settings = try container.decode(Settings.self, forKey: .settings)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(name, forKey: .name)
      try container.encode(settings, forKey: .settings)
    }
  
    public struct Settings: Codable, Sendable {
      public let apiKey: String?
      public let baseUrl: String?
    
      private enum CodingKeys: String, CodingKey {
        case apiKey = "apiKey"
        case baseUrl = "baseUrl"
      }
    
      public init(
          apiKey: String? = nil,
          baseUrl: String? = nil
      ) {
        self.apiKey = apiKey
        self.baseUrl = baseUrl
      }
    
      public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apiKey = try container.decodeIfPresent(String?.self, forKey: .apiKey)
        baseUrl = try container.decodeIfPresent(String?.self, forKey: .baseUrl)
      }
    
      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(apiKey, forKey: .apiKey)
        try container.encodeIfPresent(baseUrl, forKey: .baseUrl)
      }
    }
  }
  public enum APIProviderName: String, Codable, Sendable {
    case openai = "openai"
    case anthropic = "anthropic"
    case openrouter = "openrouter"
    case claudeCode = "claude_code"
    case groq = "groq"
    case gemini = "gemini"
  }    
  public struct Models: Codable, Sendable {
    public let id: String
    public let displayName: String
  
    private enum CodingKeys: String, CodingKey {
      case id = "id"
      case displayName = "displayName"
    }
  
    public init(
        id: String,
        displayName: String
    ) {
      self.id = id
      self.displayName = displayName
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      id = try container.decode(String.self, forKey: .id)
      displayName = try container.decode(String.self, forKey: .displayName)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(id, forKey: .id)
      try container.encode(displayName, forKey: .displayName)
    }
  }
  public struct ListModelsOutput: Codable, Sendable {
    public let models: [Models]
  
    private enum CodingKeys: String, CodingKey {
      case models = "models"
    }
  
    public init(
        models: [Models]
    ) {
      self.models = models
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      models = try container.decode([Models].self, forKey: .models)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(models, forKey: .models)
    }
  }}
