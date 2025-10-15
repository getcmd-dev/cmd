// swiftformat:disable all
// This file is generated from ./local-server/src/server/schemas/toolApprovalSchema.ts by `yarn export-schema-swift`.
// Do not edit it manually.

import Foundation
import JSONFoundation

extension Schema {
  public struct ApproveToolUseRequestParams: Codable, Sendable {
    public let toolUseId: String
    public let approvalResult: ApprovalResult
  
    private enum CodingKeys: String, CodingKey {
      case toolUseId = "toolUseId"
      case approvalResult = "approvalResult"
    }
  
    public init(
        toolUseId: String,
        approvalResult: ApprovalResult
    ) {
      self.toolUseId = toolUseId
      self.approvalResult = approvalResult
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      toolUseId = try container.decode(String.self, forKey: .toolUseId)
      approvalResult = try container.decode(ApprovalResult.self, forKey: .approvalResult)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(toolUseId, forKey: .toolUseId)
      try container.encode(approvalResult, forKey: .approvalResult)
    }
  }
  public struct ApprovalResultApprove: Codable, Sendable {
    public let type = "approval_allowed"
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
    }
  
    public init(
        type: String = "approval_allowed"
    ) {
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
    }
  }
  public struct ApprovalResultDeny: Codable, Sendable {
    public let type = "approval_denied"
    public let reason: String
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case reason = "reason"
    }
  
    public init(
        type: String = "approval_denied",
        reason: String
    ) {
      self.reason = reason
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      reason = try container.decode(String.self, forKey: .reason)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(reason, forKey: .reason)
    }
  }
  public enum ApprovalResult: Codable, Sendable {
    case approvalResultApprove(_ value: ApprovalResultApprove)
    case approvalResultDeny(_ value: ApprovalResultDeny)
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let type = try container.decode(String.self, forKey: .type)
      switch type {
        case "approval_allowed":
          self = .approvalResultApprove(try ApprovalResultApprove(from: decoder))
        case "approval_denied":
          self = .approvalResultDeny(try ApprovalResultDeny(from: decoder))
        default:
          throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid type"))
      }
    }
  
    public func encode(to encoder: Encoder) throws {
      switch self {
        case .approvalResultApprove(let value):
          try value.encode(to: encoder)
        case .approvalResultDeny(let value):
          try value.encode(to: encoder)
      }
    }
  }}
