// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - AIProvider

public struct AIProvider: Hashable, Identifiable, CaseIterable, Sendable, RawRepresentable {
  public init?(rawValue: String) {
    if let provider = AIProvider.allCases.first(where: { $0.id == rawValue }) {
      self = provider
    } else {
      return nil
    }
  }

  init(
    id: String,
    name: String,
    keychainKey: String,
    websiteURL: URL? = nil,
    apiKeyCreationURL: URL? = nil,
    lowTierModelId: AIModelID? = nil,
    modelsEnabledByDefault: [AIModelID])
  {
    self.id = id
    self.name = name
    self.keychainKey = keychainKey
    self.websiteURL = websiteURL
    self.apiKeyCreationURL = apiKeyCreationURL
    self.lowTierModelId = lowTierModelId
    self.modelsEnabledByDefault = modelsEnabledByDefault
  }

  public static var allCases: [AIProvider] {
    [
      .openRouter,
      .anthropic,
      .openAI,
      .groq,
      .gemini,
      .claudeCode,
    ]
  }

  public let id: String
  public let name: String
  public let keychainKey: String
  public let websiteURL: URL?
  public let apiKeyCreationURL: URL?
  public let lowTierModelId: AIModelID?
  public let modelsEnabledByDefault: [AIModelID]

  public var rawValue: String { id }

  public static func ==(lhs: AIProvider, rhs: AIProvider) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

}

// MARK: Codable

extension AIProvider: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let id = try container.decode(String.self)
    guard let provider = AIProvider(rawValue: id) else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid AIProvider \(id)")
    }
    self = provider
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(id)
  }
}
