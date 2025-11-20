// swiftformat:disable all
// This file is generated from ./local-server/src/server/schemas/codeCompletionSchema.ts by `yarn export-schema-swift`.
// Do not edit it manually.

import Foundation
import JSONFoundation

extension Schema {
  public struct CodeCompletionRequestParams: Codable, Sendable {
    public let model: String
    public let provider: APIProvider
    public let selection: CursorRange
    public let recentEdits: String?
    public let pasteboardContent: String?
    public let recentlyOpenedFiles: [RecentlyOpenedFile]?
    public let formattingMetadata: FileFormattingMetadata
    public let prefix: String
    public let suffix: String
    public let filepath: String
  
    private enum CodingKeys: String, CodingKey {
      case model = "model"
      case provider = "provider"
      case selection = "selection"
      case recentEdits = "recentEdits"
      case pasteboardContent = "pasteboardContent"
      case recentlyOpenedFiles = "recentlyOpenedFiles"
      case formattingMetadata = "formattingMetadata"
      case prefix = "prefix"
      case suffix = "suffix"
      case filepath = "filepath"
    }
  
    public init(
        model: String,
        provider: APIProvider,
        selection: CursorRange,
        recentEdits: String? = nil,
        pasteboardContent: String? = nil,
        recentlyOpenedFiles: [RecentlyOpenedFile]? = nil,
        formattingMetadata: FileFormattingMetadata,
        prefix: String,
        suffix: String,
        filepath: String
    ) {
      self.model = model
      self.provider = provider
      self.selection = selection
      self.recentEdits = recentEdits
      self.pasteboardContent = pasteboardContent
      self.recentlyOpenedFiles = recentlyOpenedFiles
      self.formattingMetadata = formattingMetadata
      self.prefix = prefix
      self.suffix = suffix
      self.filepath = filepath
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      model = try container.decode(String.self, forKey: .model)
      provider = try container.decode(APIProvider.self, forKey: .provider)
      selection = try container.decode(CursorRange.self, forKey: .selection)
      recentEdits = try container.decodeIfPresent(String?.self, forKey: .recentEdits)
      pasteboardContent = try container.decodeIfPresent(String?.self, forKey: .pasteboardContent)
      recentlyOpenedFiles = try container.decodeIfPresent([RecentlyOpenedFile]?.self, forKey: .recentlyOpenedFiles)
      formattingMetadata = try container.decode(FileFormattingMetadata.self, forKey: .formattingMetadata)
      prefix = try container.decode(String.self, forKey: .prefix)
      suffix = try container.decode(String.self, forKey: .suffix)
      filepath = try container.decode(String.self, forKey: .filepath)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(model, forKey: .model)
      try container.encode(provider, forKey: .provider)
      try container.encode(selection, forKey: .selection)
      try container.encodeIfPresent(recentEdits, forKey: .recentEdits)
      try container.encodeIfPresent(pasteboardContent, forKey: .pasteboardContent)
      try container.encodeIfPresent(recentlyOpenedFiles, forKey: .recentlyOpenedFiles)
      try container.encode(formattingMetadata, forKey: .formattingMetadata)
      try container.encode(prefix, forKey: .prefix)
      try container.encode(suffix, forKey: .suffix)
      try container.encode(filepath, forKey: .filepath)
    }
  }
  public struct CursorRange: Codable, Sendable {
    public let start: CursorPosition
    public let end: CursorPosition
  
    private enum CodingKeys: String, CodingKey {
      case start = "start"
      case end = "end"
    }
  
    public init(
        start: CursorPosition,
        end: CursorPosition
    ) {
      self.start = start
      self.end = end
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      start = try container.decode(CursorPosition.self, forKey: .start)
      end = try container.decode(CursorPosition.self, forKey: .end)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(start, forKey: .start)
      try container.encode(end, forKey: .end)
    }
  }
  public struct CursorPosition: Codable, Sendable {
    public let line: Double
    public let character: Double
  
    private enum CodingKeys: String, CodingKey {
      case line = "line"
      case character = "character"
    }
  
    public init(
        line: Double,
        character: Double
    ) {
      self.line = line
      self.character = character
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      line = try container.decode(Double.self, forKey: .line)
      character = try container.decode(Double.self, forKey: .character)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(line, forKey: .line)
      try container.encode(character, forKey: .character)
    }
  }
  public struct RecentlyOpenedFile: Codable, Sendable {
    public let filepath: String
    public let content: String
    public let lastAccessedAt: String?
  
    private enum CodingKeys: String, CodingKey {
      case filepath = "filepath"
      case content = "content"
      case lastAccessedAt = "lastAccessedAt"
    }
  
    public init(
        filepath: String,
        content: String,
        lastAccessedAt: String? = nil
    ) {
      self.filepath = filepath
      self.content = content
      self.lastAccessedAt = lastAccessedAt
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      filepath = try container.decode(String.self, forKey: .filepath)
      content = try container.decode(String.self, forKey: .content)
      lastAccessedAt = try container.decodeIfPresent(String?.self, forKey: .lastAccessedAt)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(filepath, forKey: .filepath)
      try container.encode(content, forKey: .content)
      try container.encodeIfPresent(lastAccessedAt, forKey: .lastAccessedAt)
    }
  }
  public struct FileFormattingMetadata: Codable, Sendable {
    public let tabSize: Double
    public let indentSize: Double
    public let usesTabsForIndentation: Bool
    public let uti: String
  
    private enum CodingKeys: String, CodingKey {
      case tabSize = "tabSize"
      case indentSize = "indentSize"
      case usesTabsForIndentation = "usesTabsForIndentation"
      case uti = "uti"
    }
  
    public init(
        tabSize: Double,
        indentSize: Double,
        usesTabsForIndentation: Bool,
        uti: String
    ) {
      self.tabSize = tabSize
      self.indentSize = indentSize
      self.usesTabsForIndentation = usesTabsForIndentation
      self.uti = uti
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      tabSize = try container.decode(Double.self, forKey: .tabSize)
      indentSize = try container.decode(Double.self, forKey: .indentSize)
      usesTabsForIndentation = try container.decode(Bool.self, forKey: .usesTabsForIndentation)
      uti = try container.decode(String.self, forKey: .uti)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(tabSize, forKey: .tabSize)
      try container.encode(indentSize, forKey: .indentSize)
      try container.encode(usesTabsForIndentation, forKey: .usesTabsForIndentation)
      try container.encode(uti, forKey: .uti)
    }
  }
  public struct CodeCompletionResponseParams: Codable, Sendable {
    public let choices: [Choices]
  
    private enum CodingKeys: String, CodingKey {
      case choices = "choices"
    }
  
    public init(
        choices: [Choices]
    ) {
      self.choices = choices
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      choices = try container.decode([Choices].self, forKey: .choices)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(choices, forKey: .choices)
    }
  
    public struct Choices: Codable, Sendable {
      public let text: String
      public let newContent: String
      public let changedRange: ChangedRange?
    
      private enum CodingKeys: String, CodingKey {
        case text = "text"
        case newContent = "newContent"
        case changedRange = "changedRange"
      }
    
      public init(
          text: String,
          newContent: String,
          changedRange: ChangedRange? = nil
      ) {
        self.text = text
        self.newContent = newContent
        self.changedRange = changedRange
      }
    
      public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        newContent = try container.decode(String.self, forKey: .newContent)
        changedRange = try container.decodeIfPresent(ChangedRange?.self, forKey: .changedRange)
      }
    
      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encode(newContent, forKey: .newContent)
        try container.encodeIfPresent(changedRange, forKey: .changedRange)
      }
    
      public struct ChangedRange: Codable, Sendable {
        public let start: CursorPosition
        public let end: CursorPosition
      
        private enum CodingKeys: String, CodingKey {
          case start = "start"
          case end = "end"
        }
      
        public init(
            start: CursorPosition,
            end: CursorPosition
        ) {
          self.start = start
          self.end = end
        }
      
        public init(from decoder: Decoder) throws {
          let container = try decoder.container(keyedBy: CodingKeys.self)
          start = try container.decode(CursorPosition.self, forKey: .start)
          end = try container.decode(CursorPosition.self, forKey: .end)
        }
      
        public func encode(to encoder: Encoder) throws {
          var container = encoder.container(keyedBy: CodingKeys.self)
          try container.encode(start, forKey: .start)
          try container.encode(end, forKey: .end)
        }
      }
    }
  }}
