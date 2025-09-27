// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatFoundation
import Foundation
import JSONFoundation
import MCP
import ThreadSafe
import ToolFoundation

public typealias MCPToolInput = [String: JSON.Value]

public typealias MCPToolOutput = JSON.Value

// MARK: - MCPTool

final class MCPTool: NonStreamableTool {
  init(tool: MCP.Tool, client: MCP.Client, serverName: String) {
    wrappedTool = tool
    self.client = client
    self.serverName = serverName
  }

  @ThreadSafe
  final class Use: NonStreamableToolUse, UpdatableToolUse {

    init(
      callingTool: MCPTool,
      toolUseId: String,
      input: Input,
      context: ToolFoundation.ToolExecutionContext,
      internalState _: InternalState? = nil,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.input = input
      self.context = context

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted)
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    typealias InternalState = EmptyObject

    typealias Input = MCPToolInput

    typealias Output = MCPToolOutput

    let context: ToolFoundation.ToolExecutionContext

    let callingTool: MCPTool
    let toolUseId: String
    let input: Input

    let status: Status

    let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    var isReadonly: Bool {
      callingTool.isReadonly
    }

    func startExecuting() {
      // Transition from pendingApproval to notStarted to running
      updateStatus.yield(.notStarted)
      updateStatus.yield(.running)

      Task {
        do {
          let response = try await callingTool.client.callTool(name: callingTool.name, arguments: input.mapValues { $0.asValue })
          if response.isError == true {
            var errorDescription = "unknown error"
            errorDescription = (try? JSONEncoder().encode(response.content))
              .map { String(data: $0, encoding: .utf8) } ??? errorDescription
            updateStatus.complete(with: .failure(AppError("MCP tool returned an error: \(errorDescription)")))
          } else {
            updateStatus.complete(with: .success(.array(response.content.map(\.jsonValue))))
          }
        } catch { }
      }
    }

    func cancel() {
      updateStatus.complete(with: .failure(CancellationError()))
    }

  }

  var name: String {
    "mcp__\(serverName)__\(wrappedTool.name)".sanitized
  }

  var description: String {
    wrappedTool.description ?? "MCP tool \(name) (no description)"
  }

  var inputSchema: JSON {
    switch wrappedTool.inputSchema.jsonValue {
    case .object(let value):
      return .object(value)
    case .array(let value):
      return .array(value)
    default:
      break
    }
    return .object([:])
  }

  var isReadonly: Bool {
    if wrappedTool.annotations.destructiveHint == true {
      return false
    }
    if wrappedTool.annotations.readOnlyHint == true {
      return true
    }
    // Not specified, err on on the side of caution.
    return false
  }

  var displayName: String {
    "\(wrappedTool.name) (MCP)"
  }

  var shortDescription: String {
    description
  }

  func isAvailable(in mode: ChatMode) -> Bool {
    isReadonly ? true : mode == .agent
  }

  private let serverName: String

  private let client: MCP.Client
  private let wrappedTool: MCP.Tool

}

extension MCP.Value {
  var jsonValue: JSON.Value? {
    switch self {
    case .null:
      return .null

    case .bool(let value):
      return .bool(value)

    case .int(let value):
      return .number(Double(value))

    case .double(let value):
      return .number(value)

    case .string(let value):
      return .string(value)

    case .data:
      assertionFailure("Data value cannot be represented in JSON")
      return nil

    case .array(let array):
      return .array(array.compactMap(\.jsonValue))

    case .object(let object):
      return .object(object.compactMapValues { $0.jsonValue })
    }
  }
}

extension JSON.Value {
  var asValue: MCP.Value {
    switch self {
    case .null:
      .null
    case .bool(let value):
      .bool(value)
    case .number(let value):
      .double(value)
    case .string(let value):
      .string(value)
    case .array(let array):
      .array(array.map(\.asValue))
    case .object(let object):
      .object(object.mapValues { $0.asValue })
    }
  }
}

extension MCP.Tool.Content {
  var jsonValue: JSON.Value {
    switch self {
    case .text(let text):
      return .string(text)

    case .audio:
      assertionFailure("Audio content cannot be represented in JSON")
      return .string("<audio content>")

    case .image(data: _, mimeType: _, metadata: _):
      assertionFailure("Image content cannot be represented in JSON")
      return .string("<image content>")

    case .resource(uri: _, mimeType: _, text: _):
      assertionFailure("Resource content cannot be represented in JSON")
      return .string("<resource content>")
    }
  }
}

extension String {
  /// snake case, only alphanumeric and underscores characters
  var sanitized: String {
    let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
    return replacingOccurrences(of: "([a-z])([A-Z])", with: "$1_$2", options: .regularExpression)
      .lowercased()
      .replacingOccurrences(of: " ", with: "_")
      .components(separatedBy: allowedCharacters.inverted)
      .joined()
  }
}
