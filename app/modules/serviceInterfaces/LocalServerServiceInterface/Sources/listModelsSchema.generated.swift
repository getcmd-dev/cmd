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
