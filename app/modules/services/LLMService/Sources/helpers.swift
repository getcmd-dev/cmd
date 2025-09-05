// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import Foundation
import JSONFoundation
import LLMServiceInterface
import LocalServerServiceInterface
import ToolFoundation

extension AssistantMessageContent {
  var asText: MutableCurrentValueStream<TextContentMessage>? {
    if case .text(let message) = self {
      return message
    }
    return nil
  }

  var asToolUseRequest: ToolUseMessage? {
    if case .tool(let message) = self {
      return message
    }
    return nil
  }

  var asReasoning: MutableCurrentValueStream<ReasoningContentMessage>? {
    if case .reasoning(let message) = self {
      return message
    }
    return nil
  }
}

extension AssistantMessage {
  var message: Schema.Message {
    get throws {
      try Schema.Message(role: .assistant, content: content.map { content in
        switch content {
        case .text(let text):
          return .textMessage(Schema.TextMessage(text: text.content))

        case .tool(let toolUse):
          let toolUse = toolUse.toolUse
          let request = try Schema.ToolUseRequest(name: toolUse.callingTool.name, anyInput: toolUse.input, id: toolUse.toolUseId)
          return .toolUseRequest(request)

        case .reasoning(let reasoning):
          return .reasoningMessage(Schema.ReasoningMessage(
            text: reasoning.content,
            signature: reasoning.signature))

        case .internalContent(let content):
          return .internalContent(content)
        }
      })
    }
  }
}

extension Schema.ToolResultMessage {
  public init(request: Schema.ToolUseRequest, output: JSON.Value) {
    self.init(
      toolUseId: request.toolUseId,
      toolName: request.toolName,
      result: .toolResultSuccessMessage(.init(success: output)))
  }
}

extension Schema.ToolResultMessage.Result {
  static func success(_ output: JSON.Value) -> Self {
    .toolResultSuccessMessage(.init(success: output))
  }

  static func failure(_ error: JSON.Value) -> Self {
    .toolResultFailureMessage(.init(failure: error))
  }

  static func failure(_ error: Error) -> Self {
    .failure(error.localizedDescription)
  }

  static func failure(_ errorDescription: String) -> Self {
    .failure(["error": .string(errorDescription)])
  }
}

extension DecodingError {
  /// A detailed description that is meant to send enough debugging information back to the LLM
  var llmErrorDescription: String {
    switch self {
    case .valueNotFound(let type, let context):
      return context.llmErrorDescription
    case .dataCorrupted(let context):
      return context.llmErrorDescription
    case .typeMismatch(let type, let context):
      return context.llmErrorDescription
    case .keyNotFound(let key, let context):
      return context.llmErrorDescription
    @unknown default:
      return localizedDescription
    }
  }
}

extension DecodingError.Context {
  var llmErrorDescription: String {
    var description = "Error at coding path: '\(codingPath.description)': " + debugDescription
    if let underlyingError, let debugDescription = (underlyingError as NSError).userInfo[NSDebugDescriptionErrorKey] as? String {
      description += " Underlying error: \(debugDescription)"
    }
    return description
  }
}

extension [any CodingKey] {
  var description: String {
    var description = ""
    for key in self {
      if let i = key.intValue {
        description += "[\(i)]"
      } else {
        description += ".\(key.stringValue)"
      }
    }
    return description
  }
}
