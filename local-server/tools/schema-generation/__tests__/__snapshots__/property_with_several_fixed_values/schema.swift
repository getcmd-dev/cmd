// swiftformat:disable all
// This file is generated from ./local-server/src/server/schemas/schemaFile.ts by `yarn export-schema-swift`.
// Do not edit it manually.

import Foundation
import JSONFoundation

extension Schema {
  public struct Message: Codable, Sendable {
    public let role: Role
    public let singleValue = "single_value"
  
    private enum CodingKeys: String, CodingKey {
      case role = "role"
      case singleValue = "single_value"
    }
  
    public init(
        role: Role,
        singleValue: String = "single_value"
    ) {
      self.role = role
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      role = try container.decode(Role.self, forKey: .role)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(role, forKey: .role)
      try container.encode(singleValue, forKey: .singleValue)
    }
  
    public enum Role: String, Codable, Sendable, CaseIterable {
      case system = "system"
      case user = "user"
      case assistant = "assistant"
      case functionCall = "function_call"
    }
  }}
