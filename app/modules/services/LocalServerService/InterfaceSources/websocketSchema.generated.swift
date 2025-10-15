// swiftformat:disable all
// This file is generated from ./local-server/src/server/schemas/websocketSchema.ts by `yarn export-schema-swift`.
// Do not edit it manually.

import Foundation
import JSONFoundation

extension Schema {
  public struct WebSocketMessage: Codable, Sendable {
    public let channel: String
    public let id: String
    public let data: JSON
  
    private enum CodingKeys: String, CodingKey {
      case channel = "channel"
      case id = "id"
      case data = "data"
    }
  
    public init(
        channel: String,
        id: String,
        data: JSON
    ) {
      self.channel = channel
      self.id = id
      self.data = data
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      channel = try container.decode(String.self, forKey: .channel)
      id = try container.decode(String.self, forKey: .id)
      data = try container.decode(JSON.self, forKey: .data)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(channel, forKey: .channel)
      try container.encode(id, forKey: .id)
      try container.encode(data, forKey: .data)
    }
  }}
