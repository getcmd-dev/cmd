// swiftformat:disable all
// This file is generated from ./local-server/src/server/schemas/toolsSchema.ts by `yarn export-schema-swift`.
// Do not edit it manually.

import Foundation
import JSONFoundation

extension ToolsSchema {
  public struct LSToolInput: Codable, Sendable {
    public let type = "list_files_input"
    public let path: String
    public let recursive: Bool?
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case path = "path"
      case recursive = "recursive"
    }
  
    public init(
        type: String = "list_files_input",
        path: String,
        recursive: Bool? = nil
    ) {
      self.path = path
      self.recursive = recursive
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      path = try container.decode(String.self, forKey: .path)
      recursive = try container.decodeIfPresent(Bool?.self, forKey: .recursive)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(path, forKey: .path)
      try container.encodeIfPresent(recursive, forKey: .recursive)
    }
  }
  public struct AskFollowUpToolInput: Codable, Sendable {
    public let type = "ask_followup_input"
    public let question: String
    public let followUp: [String]
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case question = "question"
      case followUp = "followUp"
    }
  
    public init(
        type: String = "ask_followup_input",
        question: String,
        followUp: [String]
    ) {
      self.question = question
      self.followUp = followUp
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      question = try container.decode(String.self, forKey: .question)
      followUp = try container.decode([String].self, forKey: .followUp)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(question, forKey: .question)
      try container.encode(followUp, forKey: .followUp)
    }
  }
  public struct EditFilesToolInput: Codable, Sendable {
    public let type = "edit_files_input"
    public let files: [EditFilesToolInput_FileChange]
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case files = "files"
    }
  
    public init(
        type: String = "edit_files_input",
        files: [EditFilesToolInput_FileChange]
    ) {
      self.files = files
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      files = try container.decode([EditFilesToolInput_FileChange].self, forKey: .files)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(files, forKey: .files)
    }
  }
  public struct ExecuteCommandToolInput: Codable, Sendable {
    public let type = "execute_command_input"
    public let command: String
    public let cwd: String?
    public let canModifySourceFiles: Bool
    public let canModifyDerivedFiles: Bool
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case command = "command"
      case cwd = "cwd"
      case canModifySourceFiles = "canModifySourceFiles"
      case canModifyDerivedFiles = "canModifyDerivedFiles"
    }
  
    public init(
        type: String = "execute_command_input",
        command: String,
        cwd: String? = nil,
        canModifySourceFiles: Bool,
        canModifyDerivedFiles: Bool
    ) {
      self.command = command
      self.cwd = cwd
      self.canModifySourceFiles = canModifySourceFiles
      self.canModifyDerivedFiles = canModifyDerivedFiles
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      command = try container.decode(String.self, forKey: .command)
      cwd = try container.decodeIfPresent(String?.self, forKey: .cwd)
      canModifySourceFiles = try container.decode(Bool.self, forKey: .canModifySourceFiles)
      canModifyDerivedFiles = try container.decode(Bool.self, forKey: .canModifyDerivedFiles)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(command, forKey: .command)
      try container.encodeIfPresent(cwd, forKey: .cwd)
      try container.encode(canModifySourceFiles, forKey: .canModifySourceFiles)
      try container.encode(canModifyDerivedFiles, forKey: .canModifyDerivedFiles)
    }
  }
  public struct ReadFileToolInput: Codable, Sendable {
    public let type = "read_file_input"
    public let path: String
    public let lineRange: ReadFileToolInput_Range?
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case path = "path"
      case lineRange = "lineRange"
    }
  
    public init(
        type: String = "read_file_input",
        path: String,
        lineRange: ReadFileToolInput_Range? = nil
    ) {
      self.path = path
      self.lineRange = lineRange
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      path = try container.decode(String.self, forKey: .path)
      lineRange = try container.decodeIfPresent(ReadFileToolInput_Range?.self, forKey: .lineRange)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(path, forKey: .path)
      try container.encodeIfPresent(lineRange, forKey: .lineRange)
    }
  }
  public struct SearchFilesToolInput: Codable, Sendable {
    public let type = "search_files_input"
    public let directoryPath: String?
    public let regex: String
    public let filePattern: String?
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case directoryPath = "directoryPath"
      case regex = "regex"
      case filePattern = "filePattern"
    }
  
    public init(
        type: String = "search_files_input",
        directoryPath: String? = nil,
        regex: String,
        filePattern: String? = nil
    ) {
      self.directoryPath = directoryPath
      self.regex = regex
      self.filePattern = filePattern
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      directoryPath = try container.decodeIfPresent(String?.self, forKey: .directoryPath)
      regex = try container.decode(String.self, forKey: .regex)
      filePattern = try container.decodeIfPresent(String?.self, forKey: .filePattern)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encodeIfPresent(directoryPath, forKey: .directoryPath)
      try container.encode(regex, forKey: .regex)
      try container.encodeIfPresent(filePattern, forKey: .filePattern)
    }
  }
  public struct GlobToolInput: Codable, Sendable {
    public let type = "glob_input"
    public let pattern: String
    public let path: String?
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case pattern = "pattern"
      case path = "path"
    }
  
    public init(
        type: String = "glob_input",
        pattern: String,
        path: String? = nil
    ) {
      self.pattern = pattern
      self.path = path
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      pattern = try container.decode(String.self, forKey: .pattern)
      path = try container.decodeIfPresent(String?.self, forKey: .path)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(pattern, forKey: .pattern)
      try container.encodeIfPresent(path, forKey: .path)
    }
  }
  public struct TodoWriteToolInput: Codable, Sendable {
    public let type = "todo_write_input"
    public let todos: [TodoWriteToolInput_TodoItem]
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case todos = "todos"
    }
  
    public init(
        type: String = "todo_write_input",
        todos: [TodoWriteToolInput_TodoItem]
    ) {
      self.todos = todos
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      todos = try container.decode([TodoWriteToolInput_TodoItem].self, forKey: .todos)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(todos, forKey: .todos)
    }
  }
  public struct WebFetchToolInput: Codable, Sendable {
    public let type = "web_fetch_input"
    public let url: String
    public let prompt: String
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case url = "url"
      case prompt = "prompt"
    }
  
    public init(
        type: String = "web_fetch_input",
        url: String,
        prompt: String
    ) {
      self.url = url
      self.prompt = prompt
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      url = try container.decode(String.self, forKey: .url)
      prompt = try container.decode(String.self, forKey: .prompt)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(url, forKey: .url)
      try container.encode(prompt, forKey: .prompt)
    }
  }
  public struct WebSearchToolInput: Codable, Sendable {
    public let type = "web_search_input"
    public let query: String
    public let allowedDomains: [String]?
    public let blockedDomains: [String]?
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case query = "query"
      case allowedDomains = "allowed_domains"
      case blockedDomains = "blocked_domains"
    }
  
    public init(
        type: String = "web_search_input",
        query: String,
        allowedDomains: [String]? = nil,
        blockedDomains: [String]? = nil
    ) {
      self.query = query
      self.allowedDomains = allowedDomains
      self.blockedDomains = blockedDomains
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      query = try container.decode(String.self, forKey: .query)
      allowedDomains = try container.decodeIfPresent([String]?.self, forKey: .allowedDomains)
      blockedDomains = try container.decodeIfPresent([String]?.self, forKey: .blockedDomains)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(query, forKey: .query)
      try container.encodeIfPresent(allowedDomains, forKey: .allowedDomains)
      try container.encodeIfPresent(blockedDomains, forKey: .blockedDomains)
    }
  }
  public enum InternalToolInputSchemas: Codable, Sendable {
    case lSToolInput(_ value: LSToolInput)
    case askFollowUpToolInput(_ value: AskFollowUpToolInput)
    case editFilesToolInput(_ value: EditFilesToolInput)
    case executeCommandToolInput(_ value: ExecuteCommandToolInput)
    case readFileToolInput(_ value: ReadFileToolInput)
    case searchFilesToolInput(_ value: SearchFilesToolInput)
    case globToolInput(_ value: GlobToolInput)
    case todoWriteToolInput(_ value: TodoWriteToolInput)
    case webFetchToolInput(_ value: WebFetchToolInput)
    case webSearchToolInput(_ value: WebSearchToolInput)
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let type = try container.decode(String.self, forKey: .type)
      switch type {
        case "list_files_input":
          self = .lSToolInput(try LSToolInput(from: decoder))
        case "ask_followup_input":
          self = .askFollowUpToolInput(try AskFollowUpToolInput(from: decoder))
        case "edit_files_input":
          self = .editFilesToolInput(try EditFilesToolInput(from: decoder))
        case "execute_command_input":
          self = .executeCommandToolInput(try ExecuteCommandToolInput(from: decoder))
        case "read_file_input":
          self = .readFileToolInput(try ReadFileToolInput(from: decoder))
        case "search_files_input":
          self = .searchFilesToolInput(try SearchFilesToolInput(from: decoder))
        case "glob_input":
          self = .globToolInput(try GlobToolInput(from: decoder))
        case "todo_write_input":
          self = .todoWriteToolInput(try TodoWriteToolInput(from: decoder))
        case "web_fetch_input":
          self = .webFetchToolInput(try WebFetchToolInput(from: decoder))
        case "web_search_input":
          self = .webSearchToolInput(try WebSearchToolInput(from: decoder))
        default:
          throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid type"))
      }
    }
  
    public func encode(to encoder: Encoder) throws {
      switch self {
        case .lSToolInput(let value):
          try value.encode(to: encoder)
        case .askFollowUpToolInput(let value):
          try value.encode(to: encoder)
        case .editFilesToolInput(let value):
          try value.encode(to: encoder)
        case .executeCommandToolInput(let value):
          try value.encode(to: encoder)
        case .readFileToolInput(let value):
          try value.encode(to: encoder)
        case .searchFilesToolInput(let value):
          try value.encode(to: encoder)
        case .globToolInput(let value):
          try value.encode(to: encoder)
        case .todoWriteToolInput(let value):
          try value.encode(to: encoder)
        case .webFetchToolInput(let value):
          try value.encode(to: encoder)
        case .webSearchToolInput(let value):
          try value.encode(to: encoder)
      }
    }
  }
  public struct EditFilesToolInput_FileChange: Codable, Sendable {
    public let path: String
    public let isNewFile: Bool?
    public let changes: [EditFilesToolInput_Change]
  
    private enum CodingKeys: String, CodingKey {
      case path = "path"
      case isNewFile = "isNewFile"
      case changes = "changes"
    }
  
    public init(
        path: String,
        isNewFile: Bool? = nil,
        changes: [EditFilesToolInput_Change]
    ) {
      self.path = path
      self.isNewFile = isNewFile
      self.changes = changes
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      path = try container.decode(String.self, forKey: .path)
      isNewFile = try container.decodeIfPresent(Bool?.self, forKey: .isNewFile)
      changes = try container.decode([EditFilesToolInput_Change].self, forKey: .changes)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(path, forKey: .path)
      try container.encodeIfPresent(isNewFile, forKey: .isNewFile)
      try container.encode(changes, forKey: .changes)
    }
  }
  public struct EditFilesToolInput_Change: Codable, Sendable {
    public let search: String
    public let replace: String
  
    private enum CodingKeys: String, CodingKey {
      case search = "search"
      case replace = "replace"
    }
  
    public init(
        search: String,
        replace: String
    ) {
      self.search = search
      self.replace = replace
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      search = try container.decode(String.self, forKey: .search)
      replace = try container.decode(String.self, forKey: .replace)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(search, forKey: .search)
      try container.encode(replace, forKey: .replace)
    }
  }
  public struct ReadFileToolInput_Range: Codable, Sendable {
    public let start: Int
    public let end: Int
  
    private enum CodingKeys: String, CodingKey {
      case start = "start"
      case end = "end"
    }
  
    public init(
        start: Int,
        end: Int
    ) {
      self.start = start
      self.end = end
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      start = try container.decode(Int.self, forKey: .start)
      end = try container.decode(Int.self, forKey: .end)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(start, forKey: .start)
      try container.encode(end, forKey: .end)
    }
  }
  public struct TodoWriteToolInput_TodoItem: Codable, Sendable {
    public let content: String
    public let status: String
  
    private enum CodingKeys: String, CodingKey {
      case content = "content"
      case status = "status"
    }
  
    public init(
        content: String,
        status: String
    ) {
      self.content = content
      self.status = status
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      content = try container.decode(String.self, forKey: .content)
      status = try container.decode(String.self, forKey: .status)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(content, forKey: .content)
      try container.encode(status, forKey: .status)
    }
  }
  public struct LSToolOutput: Codable, Sendable {
    public let type = "list_files_output"
    public let files: [LSToolOutput_File]
    public let hasMore: Bool
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case files = "files"
      case hasMore = "hasMore"
    }
  
    public init(
        type: String = "list_files_output",
        files: [LSToolOutput_File],
        hasMore: Bool
    ) {
      self.files = files
      self.hasMore = hasMore
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      files = try container.decode([LSToolOutput_File].self, forKey: .files)
      hasMore = try container.decode(Bool.self, forKey: .hasMore)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(files, forKey: .files)
      try container.encode(hasMore, forKey: .hasMore)
    }
  }
  public struct AskFollowUpToolOutput: Codable, Sendable {
    public let type = "ask_followup_output"
    public let response: String
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case response = "response"
    }
  
    public init(
        type: String = "ask_followup_output",
        response: String
    ) {
      self.response = response
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      response = try container.decode(String.self, forKey: .response)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(response, forKey: .response)
    }
  }
  public struct EditFilesToolOutput: Codable, Sendable {
    public let type = "edit_files_output"
    public let result: String
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case result = "result"
    }
  
    public init(
        type: String = "edit_files_output",
        result: String
    ) {
      self.result = result
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      result = try container.decode(String.self, forKey: .result)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(result, forKey: .result)
    }
  }
  public struct ExecuteCommandToolOutput: Codable, Sendable {
    public let type = "execute_command_output"
    public let output: String?
    public let exitCode: Int
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case output = "output"
      case exitCode = "exitCode"
    }
  
    public init(
        type: String = "execute_command_output",
        output: String? = nil,
        exitCode: Int
    ) {
      self.output = output
      self.exitCode = exitCode
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      output = try container.decodeIfPresent(String?.self, forKey: .output)
      exitCode = try container.decode(Int.self, forKey: .exitCode)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encodeIfPresent(output, forKey: .output)
      try container.encode(exitCode, forKey: .exitCode)
    }
  }
  public struct ReadFileToolOutput: Codable, Sendable {
    public let type = "read_file_output"
    public let content: String
    public let uri: String?
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case content = "content"
      case uri = "uri"
    }
  
    public init(
        type: String = "read_file_output",
        content: String,
        uri: String? = nil
    ) {
      self.content = content
      self.uri = uri
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      content = try container.decode(String.self, forKey: .content)
      uri = try container.decodeIfPresent(String?.self, forKey: .uri)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(content, forKey: .content)
      try container.encodeIfPresent(uri, forKey: .uri)
    }
  }
  public struct SearchFilesToolOutput: Codable, Sendable {
    public let type = "search_files_output"
    public let outputForLLm: String
    public let results: [SearchFileResult]
    public let hasMore: Bool
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case outputForLLm = "outputForLLm"
      case results = "results"
      case hasMore = "hasMore"
    }
  
    public init(
        type: String = "search_files_output",
        outputForLLm: String,
        results: [SearchFileResult],
        hasMore: Bool
    ) {
      self.outputForLLm = outputForLLm
      self.results = results
      self.hasMore = hasMore
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      outputForLLm = try container.decode(String.self, forKey: .outputForLLm)
      results = try container.decode([SearchFileResult].self, forKey: .results)
      hasMore = try container.decode(Bool.self, forKey: .hasMore)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(outputForLLm, forKey: .outputForLLm)
      try container.encode(results, forKey: .results)
      try container.encode(hasMore, forKey: .hasMore)
    }
  }
  public struct GlobToolOutput: Codable, Sendable {
    public let type = "glob_output"
    public let files: [String]
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case files = "files"
    }
  
    public init(
        type: String = "glob_output",
        files: [String]
    ) {
      self.files = files
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      files = try container.decode([String].self, forKey: .files)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(files, forKey: .files)
    }
  }
  public struct TodoWriteToolOutput: Codable, Sendable {
    public let type = "todo_write_output"
    public let message: String
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case message = "message"
    }
  
    public init(
        type: String = "todo_write_output",
        message: String
    ) {
      self.message = message
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      message = try container.decode(String.self, forKey: .message)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(message, forKey: .message)
    }
  }
  public struct WebFetchToolOutput: Codable, Sendable {
    public let type = "web_fetch_output"
    public let result: String
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case result = "result"
    }
  
    public init(
        type: String = "web_fetch_output",
        result: String
    ) {
      self.result = result
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      result = try container.decode(String.self, forKey: .result)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(result, forKey: .result)
    }
  }
  public struct WebSearchToolOutput: Codable, Sendable {
    public let type = "web_search_output"
    public let links: [WebSearchToolOutput_SearchResult]
    public let content: String
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case links = "links"
      case content = "content"
    }
  
    public init(
        type: String = "web_search_output",
        links: [WebSearchToolOutput_SearchResult],
        content: String
    ) {
      self.links = links
      self.content = content
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      links = try container.decode([WebSearchToolOutput_SearchResult].self, forKey: .links)
      content = try container.decode(String.self, forKey: .content)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(links, forKey: .links)
      try container.encode(content, forKey: .content)
    }
  }
  public enum InternalToolOutputSchemas: Codable, Sendable {
    case lSToolOutput(_ value: LSToolOutput)
    case askFollowUpToolOutput(_ value: AskFollowUpToolOutput)
    case editFilesToolOutput(_ value: EditFilesToolOutput)
    case executeCommandToolOutput(_ value: ExecuteCommandToolOutput)
    case readFileToolOutput(_ value: ReadFileToolOutput)
    case searchFilesToolOutput(_ value: SearchFilesToolOutput)
    case globToolOutput(_ value: GlobToolOutput)
    case todoWriteToolOutput(_ value: TodoWriteToolOutput)
    case webFetchToolOutput(_ value: WebFetchToolOutput)
    case webSearchToolOutput(_ value: WebSearchToolOutput)
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let type = try container.decode(String.self, forKey: .type)
      switch type {
        case "list_files_output":
          self = .lSToolOutput(try LSToolOutput(from: decoder))
        case "ask_followup_output":
          self = .askFollowUpToolOutput(try AskFollowUpToolOutput(from: decoder))
        case "edit_files_output":
          self = .editFilesToolOutput(try EditFilesToolOutput(from: decoder))
        case "execute_command_output":
          self = .executeCommandToolOutput(try ExecuteCommandToolOutput(from: decoder))
        case "read_file_output":
          self = .readFileToolOutput(try ReadFileToolOutput(from: decoder))
        case "search_files_output":
          self = .searchFilesToolOutput(try SearchFilesToolOutput(from: decoder))
        case "glob_output":
          self = .globToolOutput(try GlobToolOutput(from: decoder))
        case "todo_write_output":
          self = .todoWriteToolOutput(try TodoWriteToolOutput(from: decoder))
        case "web_fetch_output":
          self = .webFetchToolOutput(try WebFetchToolOutput(from: decoder))
        case "web_search_output":
          self = .webSearchToolOutput(try WebSearchToolOutput(from: decoder))
        default:
          throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid type"))
      }
    }
  
    public func encode(to encoder: Encoder) throws {
      switch self {
        case .lSToolOutput(let value):
          try value.encode(to: encoder)
        case .askFollowUpToolOutput(let value):
          try value.encode(to: encoder)
        case .editFilesToolOutput(let value):
          try value.encode(to: encoder)
        case .executeCommandToolOutput(let value):
          try value.encode(to: encoder)
        case .readFileToolOutput(let value):
          try value.encode(to: encoder)
        case .searchFilesToolOutput(let value):
          try value.encode(to: encoder)
        case .globToolOutput(let value):
          try value.encode(to: encoder)
        case .todoWriteToolOutput(let value):
          try value.encode(to: encoder)
        case .webFetchToolOutput(let value):
          try value.encode(to: encoder)
        case .webSearchToolOutput(let value):
          try value.encode(to: encoder)
      }
    }
  }
  public struct LSToolOutput_File: Codable, Sendable {
    public let path: String
    public let attr: String?
    public let size: String?
  
    private enum CodingKeys: String, CodingKey {
      case path = "path"
      case attr = "attr"
      case size = "size"
    }
  
    public init(
        path: String,
        attr: String? = nil,
        size: String? = nil
    ) {
      self.path = path
      self.attr = attr
      self.size = size
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      path = try container.decode(String.self, forKey: .path)
      attr = try container.decodeIfPresent(String?.self, forKey: .attr)
      size = try container.decodeIfPresent(String?.self, forKey: .size)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(path, forKey: .path)
      try container.encodeIfPresent(attr, forKey: .attr)
      try container.encodeIfPresent(size, forKey: .size)
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
  }
  public struct WebSearchToolOutput_SearchResult: Codable, Sendable {
    public let title: String
    public let url: String
  
    private enum CodingKeys: String, CodingKey {
      case title = "title"
      case url = "url"
    }
  
    public init(
        title: String,
        url: String
    ) {
      self.title = title
      self.url = url
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      title = try container.decode(String.self, forKey: .title)
      url = try container.decode(String.self, forKey: .url)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(title, forKey: .title)
      try container.encode(url, forKey: .url)
    }
  }}
