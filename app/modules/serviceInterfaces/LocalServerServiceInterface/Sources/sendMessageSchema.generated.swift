// swiftformat:disable all
// This file is generated from ./local-server/src/server/schemas/sendMessageSchema.ts by `yarn export-schema-swift`.
// Do not edit it manually.

import Foundation
import JSONFoundation

extension Schema {
  public struct SendMessageRequestParams: Codable, Sendable {
    public let messages: [Message]
    public let system: String?
    public let projectRoot: String?
    public let tools: [Tool]?
    public let model: String
    public let enableReasoning: Bool
    public let provider: APIProvider
    public let threadId: String?
  
    private enum CodingKeys: String, CodingKey {
      case messages = "messages"
      case system = "system"
      case projectRoot = "projectRoot"
      case tools = "tools"
      case model = "model"
      case enableReasoning = "enableReasoning"
      case provider = "provider"
      case threadId = "threadId"
    }
  
    public init(
        messages: [Message],
        system: String? = nil,
        projectRoot: String? = nil,
        tools: [Tool]? = nil,
        model: String,
        enableReasoning: Bool,
        provider: APIProvider,
        threadId: String? = nil
    ) {
      self.messages = messages
      self.system = system
      self.projectRoot = projectRoot
      self.tools = tools
      self.model = model
      self.enableReasoning = enableReasoning
      self.provider = provider
      self.threadId = threadId
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      messages = try container.decode([Message].self, forKey: .messages)
      system = try container.decodeIfPresent(String?.self, forKey: .system)
      projectRoot = try container.decodeIfPresent(String?.self, forKey: .projectRoot)
      tools = try container.decodeIfPresent([Tool]?.self, forKey: .tools)
      model = try container.decode(String.self, forKey: .model)
      enableReasoning = try container.decode(Bool.self, forKey: .enableReasoning)
      provider = try container.decode(APIProvider.self, forKey: .provider)
      threadId = try container.decodeIfPresent(String?.self, forKey: .threadId)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(messages, forKey: .messages)
      try container.encodeIfPresent(system, forKey: .system)
      try container.encodeIfPresent(projectRoot, forKey: .projectRoot)
      try container.encodeIfPresent(tools, forKey: .tools)
      try container.encode(model, forKey: .model)
      try container.encode(enableReasoning, forKey: .enableReasoning)
      try container.encode(provider, forKey: .provider)
      try container.encodeIfPresent(threadId, forKey: .threadId)
    }
  }
  public struct Message: Codable, Sendable {
    public let role: Role
    public let content: [MessageContent]
  
    private enum CodingKeys: String, CodingKey {
      case role = "role"
      case content = "content"
    }
  
    public init(
        role: Role,
        content: [MessageContent]
    ) {
      self.role = role
      self.content = content
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      role = try container.decode(Role.self, forKey: .role)
      content = try container.decode([MessageContent].self, forKey: .content)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(role, forKey: .role)
      try container.encode(content, forKey: .content)
    }
  
    public enum Role: String, Codable, Sendable {
      case system = "system"
      case user = "user"
      case assistant = "assistant"
      case tool = "tool"
    }
  }
  public struct TextMessage: Codable, Sendable {
    public let text: String
    public let attachments: [MessageAttachment]?
    public let type = "text"
  
    private enum CodingKeys: String, CodingKey {
      case text = "text"
      case attachments = "attachments"
      case type = "type"
    }
  
    public init(
        text: String,
        attachments: [MessageAttachment]? = nil,
        type: String = "text"
    ) {
      self.text = text
      self.attachments = attachments
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      text = try container.decode(String.self, forKey: .text)
      attachments = try container.decodeIfPresent([MessageAttachment]?.self, forKey: .attachments)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(text, forKey: .text)
      try container.encodeIfPresent(attachments, forKey: .attachments)
      try container.encode(type, forKey: .type)
    }
  }
  public struct ReasoningMessage: Codable, Sendable {
    public let text: String
    public let signature: String?
    public let type = "reasoning"
  
    private enum CodingKeys: String, CodingKey {
      case text = "text"
      case signature = "signature"
      case type = "type"
    }
  
    public init(
        text: String,
        signature: String? = nil,
        type: String = "reasoning"
    ) {
      self.text = text
      self.signature = signature
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      text = try container.decode(String.self, forKey: .text)
      signature = try container.decodeIfPresent(String?.self, forKey: .signature)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(text, forKey: .text)
      try container.encodeIfPresent(signature, forKey: .signature)
      try container.encode(type, forKey: .type)
    }
  }
  public struct ToolUseRequest: Codable, Sendable {
    public let type = "tool_call"
    public let toolName: String
    public let input: JSON
    public let toolUseId: String
    public let idx: Int
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case toolName = "toolName"
      case input = "input"
      case toolUseId = "toolUseId"
      case idx = "idx"
    }
  
    public init(
        type: String = "tool_call",
        toolName: String,
        input: JSON,
        toolUseId: String,
        idx: Int
    ) {
      self.toolName = toolName
      self.input = input
      self.toolUseId = toolUseId
      self.idx = idx
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      toolName = try container.decode(String.self, forKey: .toolName)
      input = try container.decode(JSON.self, forKey: .input)
      toolUseId = try container.decode(String.self, forKey: .toolUseId)
      idx = try container.decode(Int.self, forKey: .idx)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(toolName, forKey: .toolName)
      try container.encode(input, forKey: .input)
      try container.encode(toolUseId, forKey: .toolUseId)
      try container.encode(idx, forKey: .idx)
    }
  }
  public struct ToolResultSuccessMessage: Codable, Sendable {
    public let type = "tool_result_success"
    public let success: JSON.Value
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case success = "success"
    }
  
    public init(
        type: String = "tool_result_success",
        success: JSON.Value
    ) {
      self.success = success
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      success = try container.decode(JSON.Value.self, forKey: .success)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(success, forKey: .success)
    }
  }
  public struct ToolResultFailureMessage: Codable, Sendable {
    public let type = "tool_result_failure"
    public let failure: JSON.Value
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case failure = "failure"
    }
  
    public init(
        type: String = "tool_result_failure",
        failure: JSON.Value
    ) {
      self.failure = failure
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      failure = try container.decode(JSON.Value.self, forKey: .failure)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(failure, forKey: .failure)
    }
  }
  public struct ToolResultMessage: Codable, Sendable {
    public let type = "tool_result"
    public let toolUseId: String
    public let toolName: String
    public let result: Result
    public let idx: Int?
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case toolUseId = "toolUseId"
      case toolName = "toolName"
      case result = "result"
      case idx = "idx"
    }
  
    public init(
        type: String = "tool_result",
        toolUseId: String,
        toolName: String,
        result: Result,
        idx: Int? = nil
    ) {
      self.toolUseId = toolUseId
      self.toolName = toolName
      self.result = result
      self.idx = idx
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      toolUseId = try container.decode(String.self, forKey: .toolUseId)
      toolName = try container.decode(String.self, forKey: .toolName)
      result = try container.decode(Result.self, forKey: .result)
      idx = try container.decodeIfPresent(Int?.self, forKey: .idx)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(toolUseId, forKey: .toolUseId)
      try container.encode(toolName, forKey: .toolName)
      try container.encode(result, forKey: .result)
      try container.encodeIfPresent(idx, forKey: .idx)
    }
  
    public enum Result: Codable, Sendable {
      case toolResultSuccessMessage(_ value: ToolResultSuccessMessage)
      case toolResultFailureMessage(_ value: ToolResultFailureMessage)
    
      private enum CodingKeys: String, CodingKey {
        case type = "type"
      }
    
      public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
          case "tool_result_success":
            self = .toolResultSuccessMessage(try ToolResultSuccessMessage(from: decoder))
          case "tool_result_failure":
            self = .toolResultFailureMessage(try ToolResultFailureMessage(from: decoder))
          default:
            throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid type"))
        }
      }
    
      public func encode(to encoder: Encoder) throws {
        switch self {
          case .toolResultSuccessMessage(let value):
            try value.encode(to: encoder)
          case .toolResultFailureMessage(let value):
            try value.encode(to: encoder)
        }
      }
    }
  }
  public struct InternalTextMessage: Codable, Sendable {
    public let text: String
    public let type = "internal_text"
  
    private enum CodingKeys: String, CodingKey {
      case text = "text"
      case type = "type"
    }
  
    public init(
        text: String,
        type: String = "internal_text"
    ) {
      self.text = text
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      text = try container.decode(String.self, forKey: .text)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(text, forKey: .text)
      try container.encode(type, forKey: .type)
    }
  }
  public struct InternalContent: Codable, Sendable {
    public let type = "internal_content"
    public let value: JSON
    public let idx: Int
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case value = "value"
      case idx = "idx"
    }
  
    public init(
        type: String = "internal_content",
        value: JSON,
        idx: Int
    ) {
      self.value = value
      self.idx = idx
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      value = try container.decode(JSON.self, forKey: .value)
      idx = try container.decode(Int.self, forKey: .idx)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(value, forKey: .value)
      try container.encode(idx, forKey: .idx)
    }
  }
  public enum MessageContent: Codable, Sendable {
    case textMessage(_ value: TextMessage)
    case reasoningMessage(_ value: ReasoningMessage)
    case toolUseRequest(_ value: ToolUseRequest)
    case toolResultMessage(_ value: ToolResultMessage)
    case internalTextMessage(_ value: InternalTextMessage)
    case internalContent(_ value: InternalContent)
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let type = try container.decode(String.self, forKey: .type)
      switch type {
        case "text":
          self = .textMessage(try TextMessage(from: decoder))
        case "reasoning":
          self = .reasoningMessage(try ReasoningMessage(from: decoder))
        case "tool_call":
          self = .toolUseRequest(try ToolUseRequest(from: decoder))
        case "tool_result":
          self = .toolResultMessage(try ToolResultMessage(from: decoder))
        case "internal_text":
          self = .internalTextMessage(try InternalTextMessage(from: decoder))
        case "internal_content":
          self = .internalContent(try InternalContent(from: decoder))
        default:
          throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid type"))
      }
    }
  
    public func encode(to encoder: Encoder) throws {
      switch self {
        case .textMessage(let value):
          try value.encode(to: encoder)
        case .reasoningMessage(let value):
          try value.encode(to: encoder)
        case .toolUseRequest(let value):
          try value.encode(to: encoder)
        case .toolResultMessage(let value):
          try value.encode(to: encoder)
        case .internalTextMessage(let value):
          try value.encode(to: encoder)
        case .internalContent(let value):
          try value.encode(to: encoder)
      }
    }
  }
  public struct ImageAttachment: Codable, Sendable {
    public let type = "image_attachment"
    public let url: String
    public let mimeType: String
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case url = "url"
      case mimeType = "mimeType"
    }
  
    public init(
        type: String = "image_attachment",
        url: String,
        mimeType: String
    ) {
      self.url = url
      self.mimeType = mimeType
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      url = try container.decode(String.self, forKey: .url)
      mimeType = try container.decode(String.self, forKey: .mimeType)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(url, forKey: .url)
      try container.encode(mimeType, forKey: .mimeType)
    }
  }
  public struct FileAttachment: Codable, Sendable {
    public let type = "file_attachment"
    public let path: String
    public let content: String
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case path = "path"
      case content = "content"
    }
  
    public init(
        type: String = "file_attachment",
        path: String,
        content: String
    ) {
      self.path = path
      self.content = content
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      path = try container.decode(String.self, forKey: .path)
      content = try container.decode(String.self, forKey: .content)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(path, forKey: .path)
      try container.encode(content, forKey: .content)
    }
  }
  public struct FileSelectionAttachment: Codable, Sendable {
    public let type = "file_selection_attachment"
    public let path: String
    public let content: String
    public let startLine: Int
    public let endLine: Int
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case path = "path"
      case content = "content"
      case startLine = "startLine"
      case endLine = "endLine"
    }
  
    public init(
        type: String = "file_selection_attachment",
        path: String,
        content: String,
        startLine: Int,
        endLine: Int
    ) {
      self.path = path
      self.content = content
      self.startLine = startLine
      self.endLine = endLine
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      path = try container.decode(String.self, forKey: .path)
      content = try container.decode(String.self, forKey: .content)
      startLine = try container.decode(Int.self, forKey: .startLine)
      endLine = try container.decode(Int.self, forKey: .endLine)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(path, forKey: .path)
      try container.encode(content, forKey: .content)
      try container.encode(startLine, forKey: .startLine)
      try container.encode(endLine, forKey: .endLine)
    }
  }
  public struct BuildErrorAttachment: Codable, Sendable {
    public let type = "build_error_attachment"
    public let filePath: String
    public let line: Int
    public let column: Int
    public let message: String
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case filePath = "filePath"
      case line = "line"
      case column = "column"
      case message = "message"
    }
  
    public init(
        type: String = "build_error_attachment",
        filePath: String,
        line: Int,
        column: Int,
        message: String
    ) {
      self.filePath = filePath
      self.line = line
      self.column = column
      self.message = message
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      filePath = try container.decode(String.self, forKey: .filePath)
      line = try container.decode(Int.self, forKey: .line)
      column = try container.decode(Int.self, forKey: .column)
      message = try container.decode(String.self, forKey: .message)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(filePath, forKey: .filePath)
      try container.encode(line, forKey: .line)
      try container.encode(column, forKey: .column)
      try container.encode(message, forKey: .message)
    }
  }
  public enum MessageAttachment: Codable, Sendable {
    case imageAttachment(_ value: ImageAttachment)
    case fileAttachment(_ value: FileAttachment)
    case fileSelectionAttachment(_ value: FileSelectionAttachment)
    case buildErrorAttachment(_ value: BuildErrorAttachment)
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let type = try container.decode(String.self, forKey: .type)
      switch type {
        case "image_attachment":
          self = .imageAttachment(try ImageAttachment(from: decoder))
        case "file_attachment":
          self = .fileAttachment(try FileAttachment(from: decoder))
        case "file_selection_attachment":
          self = .fileSelectionAttachment(try FileSelectionAttachment(from: decoder))
        case "build_error_attachment":
          self = .buildErrorAttachment(try BuildErrorAttachment(from: decoder))
        default:
          throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid type"))
      }
    }
  
    public func encode(to encoder: Encoder) throws {
      switch self {
        case .imageAttachment(let value):
          try value.encode(to: encoder)
        case .fileAttachment(let value):
          try value.encode(to: encoder)
        case .fileSelectionAttachment(let value):
          try value.encode(to: encoder)
        case .buildErrorAttachment(let value):
          try value.encode(to: encoder)
      }
    }
  }
  public struct Tool: Codable, Sendable {
    public let name: String
    public let description: String
    public let inputSchema: JSON
  
    private enum CodingKeys: String, CodingKey {
      case name = "name"
      case description = "description"
      case inputSchema = "inputSchema"
    }
  
    public init(
        name: String,
        description: String,
        inputSchema: JSON
    ) {
      self.name = name
      self.description = description
      self.inputSchema = inputSchema
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      name = try container.decode(String.self, forKey: .name)
      description = try container.decode(String.self, forKey: .description)
      inputSchema = try container.decode(JSON.self, forKey: .inputSchema)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(name, forKey: .name)
      try container.encode(description, forKey: .description)
      try container.encode(inputSchema, forKey: .inputSchema)
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
      public let localExecutable: LocalExecutable?
    
      private enum CodingKeys: String, CodingKey {
        case apiKey = "apiKey"
        case baseUrl = "baseUrl"
        case localExecutable = "localExecutable"
      }
    
      public init(
          apiKey: String? = nil,
          baseUrl: String? = nil,
          localExecutable: LocalExecutable? = nil
      ) {
        self.apiKey = apiKey
        self.baseUrl = baseUrl
        self.localExecutable = localExecutable
      }
    
      public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apiKey = try container.decodeIfPresent(String?.self, forKey: .apiKey)
        baseUrl = try container.decodeIfPresent(String?.self, forKey: .baseUrl)
        localExecutable = try container.decodeIfPresent(LocalExecutable?.self, forKey: .localExecutable)
      }
    
      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(apiKey, forKey: .apiKey)
        try container.encodeIfPresent(baseUrl, forKey: .baseUrl)
        try container.encodeIfPresent(localExecutable, forKey: .localExecutable)
      }
    }
  }
  public enum APIProviderName: String, Codable, Sendable {
    case openai = "openai"
    case anthropic = "anthropic"
    case openrouter = "openrouter"
    case claudeCode = "claude_code"
  }    
  public struct LocalExecutable: Codable, Sendable {
    public let executable: String
    public let env: JSON
    public let cwd: String?
  
    private enum CodingKeys: String, CodingKey {
      case executable = "executable"
      case env = "env"
      case cwd = "cwd"
    }
  
    public init(
        executable: String,
        env: JSON,
        cwd: String? = nil
    ) {
      self.executable = executable
      self.env = env
      self.cwd = cwd
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      executable = try container.decode(String.self, forKey: .executable)
      env = try container.decode(JSON.self, forKey: .env)
      cwd = try container.decodeIfPresent(String?.self, forKey: .cwd)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(executable, forKey: .executable)
      try container.encode(env, forKey: .env)
      try container.encodeIfPresent(cwd, forKey: .cwd)
    }
  }
  public struct TextDelta: Codable, Sendable {
    public let type = "text_delta"
    public let text: String
    public let idx: Int
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case text = "text"
      case idx = "idx"
    }
  
    public init(
        type: String = "text_delta",
        text: String,
        idx: Int
    ) {
      self.text = text
      self.idx = idx
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      text = try container.decode(String.self, forKey: .text)
      idx = try container.decode(Int.self, forKey: .idx)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(text, forKey: .text)
      try container.encode(idx, forKey: .idx)
    }
  }
  public struct ToolUseDelta: Codable, Sendable {
    public let type = "tool_call_delta"
    public let toolName: String
    public let inputDelta: String
    public let toolUseId: String
    public let idx: Int
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case toolName = "toolName"
      case inputDelta = "inputDelta"
      case toolUseId = "toolUseId"
      case idx = "idx"
    }
  
    public init(
        type: String = "tool_call_delta",
        toolName: String,
        inputDelta: String,
        toolUseId: String,
        idx: Int
    ) {
      self.toolName = toolName
      self.inputDelta = inputDelta
      self.toolUseId = toolUseId
      self.idx = idx
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      toolName = try container.decode(String.self, forKey: .toolName)
      inputDelta = try container.decode(String.self, forKey: .inputDelta)
      toolUseId = try container.decode(String.self, forKey: .toolUseId)
      idx = try container.decode(Int.self, forKey: .idx)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(toolName, forKey: .toolName)
      try container.encode(inputDelta, forKey: .inputDelta)
      try container.encode(toolUseId, forKey: .toolUseId)
      try container.encode(idx, forKey: .idx)
    }
  }
  public struct ResponseError: Codable, Sendable {
    public let type = "error"
    public let message: String
    public let statusCode: Int?
    public let idx: Int?
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case message = "message"
      case statusCode = "statusCode"
      case idx = "idx"
    }
  
    public init(
        type: String = "error",
        message: String,
        statusCode: Int? = nil,
        idx: Int? = nil
    ) {
      self.message = message
      self.statusCode = statusCode
      self.idx = idx
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      message = try container.decode(String.self, forKey: .message)
      statusCode = try container.decodeIfPresent(Int?.self, forKey: .statusCode)
      idx = try container.decodeIfPresent(Int?.self, forKey: .idx)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(message, forKey: .message)
      try container.encodeIfPresent(statusCode, forKey: .statusCode)
      try container.encodeIfPresent(idx, forKey: .idx)
    }
  }
  public struct ReasoningDelta: Codable, Sendable {
    public let type = "reasoning_delta"
    public let delta: String
    public let idx: Int
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case delta = "delta"
      case idx = "idx"
    }
  
    public init(
        type: String = "reasoning_delta",
        delta: String,
        idx: Int
    ) {
      self.delta = delta
      self.idx = idx
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      delta = try container.decode(String.self, forKey: .delta)
      idx = try container.decode(Int.self, forKey: .idx)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(delta, forKey: .delta)
      try container.encode(idx, forKey: .idx)
    }
  }
  public struct ReasoningSignature: Codable, Sendable {
    public let type = "reasoning_signature"
    public let signature: String
    public let idx: Int
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case signature = "signature"
      case idx = "idx"
    }
  
    public init(
        type: String = "reasoning_signature",
        signature: String,
        idx: Int
    ) {
      self.signature = signature
      self.idx = idx
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      signature = try container.decode(String.self, forKey: .signature)
      idx = try container.decode(Int.self, forKey: .idx)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(signature, forKey: .signature)
      try container.encode(idx, forKey: .idx)
    }
  }
  public struct ResponseUsage: Codable, Sendable {
    public let type = "usage"
    public let inputTokens: Int
    public let outputTokens: Int
    public let idx: Int
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case inputTokens = "inputTokens"
      case outputTokens = "outputTokens"
      case idx = "idx"
    }
  
    public init(
        type: String = "usage",
        inputTokens: Int,
        outputTokens: Int,
        idx: Int
    ) {
      self.inputTokens = inputTokens
      self.outputTokens = outputTokens
      self.idx = idx
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      inputTokens = try container.decode(Int.self, forKey: .inputTokens)
      outputTokens = try container.decode(Int.self, forKey: .outputTokens)
      idx = try container.decode(Int.self, forKey: .idx)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(inputTokens, forKey: .inputTokens)
      try container.encode(outputTokens, forKey: .outputTokens)
      try container.encode(idx, forKey: .idx)
    }
  }
  public struct Ping: Codable, Sendable {
    public let type = "ping"
    public let timestamp: Double
    public let idx: Int
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case timestamp = "timestamp"
      case idx = "idx"
    }
  
    public init(
        type: String = "ping",
        timestamp: Double,
        idx: Int
    ) {
      self.timestamp = timestamp
      self.idx = idx
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      timestamp = try container.decode(Double.self, forKey: .timestamp)
      idx = try container.decode(Int.self, forKey: .idx)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(timestamp, forKey: .timestamp)
      try container.encode(idx, forKey: .idx)
    }
  }
  public enum StreamedResponseChunk: Codable, Sendable {
    case textDelta(_ value: TextDelta)
    case toolUseRequest(_ value: ToolUseRequest)
    case toolUseDelta(_ value: ToolUseDelta)
    case toolResultMessage(_ value: ToolResultMessage)
    case responseError(_ value: ResponseError)
    case reasoningDelta(_ value: ReasoningDelta)
    case reasoningSignature(_ value: ReasoningSignature)
    case responseUsage(_ value: ResponseUsage)
    case ping(_ value: Ping)
    case internalContent(_ value: InternalContent)
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let type = try container.decode(String.self, forKey: .type)
      switch type {
        case "text_delta":
          self = .textDelta(try TextDelta(from: decoder))
        case "tool_call":
          self = .toolUseRequest(try ToolUseRequest(from: decoder))
        case "tool_call_delta":
          self = .toolUseDelta(try ToolUseDelta(from: decoder))
        case "tool_result":
          self = .toolResultMessage(try ToolResultMessage(from: decoder))
        case "error":
          self = .responseError(try ResponseError(from: decoder))
        case "reasoning_delta":
          self = .reasoningDelta(try ReasoningDelta(from: decoder))
        case "reasoning_signature":
          self = .reasoningSignature(try ReasoningSignature(from: decoder))
        case "usage":
          self = .responseUsage(try ResponseUsage(from: decoder))
        case "ping":
          self = .ping(try Ping(from: decoder))
        case "internal_content":
          self = .internalContent(try InternalContent(from: decoder))
        default:
          throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid type"))
      }
    }
  
    public func encode(to encoder: Encoder) throws {
      switch self {
        case .textDelta(let value):
          try value.encode(to: encoder)
        case .toolUseRequest(let value):
          try value.encode(to: encoder)
        case .toolUseDelta(let value):
          try value.encode(to: encoder)
        case .toolResultMessage(let value):
          try value.encode(to: encoder)
        case .responseError(let value):
          try value.encode(to: encoder)
        case .reasoningDelta(let value):
          try value.encode(to: encoder)
        case .reasoningSignature(let value):
          try value.encode(to: encoder)
        case .responseUsage(let value):
          try value.encode(to: encoder)
        case .ping(let value):
          try value.encode(to: encoder)
        case .internalContent(let value):
          try value.encode(to: encoder)
      }
    }
  }
  public struct ChatCompletionToolResponseChunk: Codable, Sendable {
    public let type = "tool_call"
    public let id: String
    public let input: JSON
    public let name: String
  
    private enum CodingKeys: String, CodingKey {
      case type = "type"
      case id = "id"
      case input = "input"
      case name = "name"
    }
  
    public init(
        type: String = "tool_call",
        id: String,
        input: JSON,
        name: String
    ) {
      self.id = id
      self.input = input
      self.name = name
    }
  
    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      id = try container.decode(String.self, forKey: .id)
      input = try container.decode(JSON.self, forKey: .input)
      name = try container.decode(String.self, forKey: .name)
    }
  
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      try container.encode(id, forKey: .id)
      try container.encode(input, forKey: .input)
      try container.encode(name, forKey: .name)
    }
  }}
