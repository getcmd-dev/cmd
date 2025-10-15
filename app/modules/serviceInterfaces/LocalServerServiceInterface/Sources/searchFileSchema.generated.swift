// swiftformat:disable all
// This file is generated from ./local-server/src/server/schemas/searchFileSchema.ts by `yarn export-schema-swift`.
// Do not edit it manually.

import Foundation
import JSONFoundation

extension Schema {
  public struct SearchFilesToolInput: Codable, Sendable {
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
  }
  public struct SearchFilesToolOutput: Codable, Sendable {
    public let outputForLLm: String
    public let results: [SearchFileResult]
    public let rootPath: String
    public let hasMore: Bool
  
    private enum CodingKeys: String, CodingKey {
      case outputForLLm = "outputForLLm"
      case results = "results"
      case rootPath = "rootPath"
      case hasMore = "hasMore"
    }
  
    public init(
        outputForLLm: String,
        results: [SearchFileResult],
        rootPath: String,
        hasMore: Bool
    ) {
      self.outputForLLm = outputForLLm
      self.results = results
      self.rootPath = rootPath
      self.hasMore = hasMore
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      outputForLLm = try container.decode(String.self, forKey: .outputForLLm)
      results = try container.decode([SearchFileResult].self, forKey: .results)
      rootPath = try container.decode(String.self, forKey: .rootPath)
      hasMore = try container.decode(Bool.self, forKey: .hasMore)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(outputForLLm, forKey: .outputForLLm)
      try container.encode(results, forKey: .results)
      try container.encode(rootPath, forKey: .rootPath)
      try container.encode(hasMore, forKey: .hasMore)
    }
  }
  public struct SearchFileResult: Codable, Sendable {
    public let path: String
    public let searchResults: [SearchResult]
  
    private enum CodingKeys: String, CodingKey {
      case path = "path"
      case searchResults = "searchResults"
    }
  
    public init(
        path: String,
        searchResults: [SearchResult]
    ) {
      self.path = path
      self.searchResults = searchResults
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      path = try container.decode(String.self, forKey: .path)
      searchResults = try container.decode([SearchResult].self, forKey: .searchResults)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(path, forKey: .path)
      try container.encode(searchResults, forKey: .searchResults)
    }
  }
  public struct SearchResult: Codable, Sendable {
    public let line: Int
    public let text: String
    public let isMatch: Bool
  
    private enum CodingKeys: String, CodingKey {
      case line = "line"
      case text = "text"
      case isMatch = "isMatch"
    }
  
    public init(
        line: Int,
        text: String,
        isMatch: Bool
    ) {
      self.line = line
      self.text = text
      self.isMatch = isMatch
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      line = try container.decode(Int.self, forKey: .line)
      text = try container.decode(String.self, forKey: .text)
      isMatch = try container.decode(Bool.self, forKey: .isMatch)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(line, forKey: .line)
      try container.encode(text, forKey: .text)
      try container.encode(isMatch, forKey: .isMatch)
    }
  }}
