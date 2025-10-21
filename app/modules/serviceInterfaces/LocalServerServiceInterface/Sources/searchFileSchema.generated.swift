// swiftformat:disable all
// This file is generated from ./local-server/src/server/schemas/searchFileSchema.ts by `yarn export-schema-swift`.
// Do not edit it manually.

import Foundation
import JSONFoundation

extension Schema {
  public struct SearchFilesRequestInput: Codable, Sendable {
    public let projectRoot: String
    public let directoryPath: String
    public let regex: String
    public let filePattern: String?
  
    private enum CodingKeys: String, CodingKey {
      case projectRoot = "projectRoot"
      case directoryPath = "directoryPath"
      case regex = "regex"
      case filePattern = "filePattern"
    }
  
    public init(
        projectRoot: String,
        directoryPath: String,
        regex: String,
        filePattern: String? = nil
    ) {
      self.projectRoot = projectRoot
      self.directoryPath = directoryPath
      self.regex = regex
      self.filePattern = filePattern
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      projectRoot = try container.decode(String.self, forKey: .projectRoot)
      directoryPath = try container.decode(String.self, forKey: .directoryPath)
      regex = try container.decode(String.self, forKey: .regex)
      filePattern = try container.decodeIfPresent(String?.self, forKey: .filePattern)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(projectRoot, forKey: .projectRoot)
      try container.encode(directoryPath, forKey: .directoryPath)
      try container.encode(regex, forKey: .regex)
      try container.encodeIfPresent(filePattern, forKey: .filePattern)
    }
  }}
