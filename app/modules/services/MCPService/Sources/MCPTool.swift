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

public final class MCPTool: NonStreamableTool {
  init(tool: MCP.Tool, client: MCP.Client, serverName: String) {
    wrappedTool = tool
    self.client = client
    self.serverName = serverName
  }

  @ThreadSafe
  public final class Use: NonStreamableToolUse, UpdatableToolUse, @unchecked Sendable {

    public init(
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

    public typealias InternalState = EmptyObject

    public typealias Input = MCPToolInput

    public typealias Output = MCPToolOutput

    public let context: ToolFoundation.ToolExecutionContext

    @MainActor
    public lazy var viewModel = DefaultToolUseViewModel(toolName: callingTool.name, status: status, input: .object(input))

    public let callingTool: MCPTool
    public let toolUseId: String
    public let input: Input

    public let status: Status

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    public var isReadonly: Bool {
      callingTool.isReadonly
    }

    public func startExecuting() {
      // Transition from pendingApproval to notStarted to running
      updateStatus.yield(.notStarted)
      updateStatus.yield(.running)

      Task {
        do {
          let response = try await callingTool.client.callTool(
            name: callingTool.externalName,
            arguments: input.mapValues { $0.asValue })
          if response.isError == true {
            var errorDescription = "unknown error"
            errorDescription = (try? JSONEncoder().encode(response.content))
              .map { String(data: $0, encoding: .utf8) } ??? errorDescription
            updateStatus.complete(with: .failure(AppError("MCP tool returned an error: \(errorDescription)")))
          } else {
            updateStatus.complete(with: .success(.array(response.content.map(\.jsonValue))))
          }
        } catch {
          updateStatus.complete(with: .failure(AppError("MCP tool returned an error: \(error.localizedDescription)")))
        }
      }
    }

    public func cancel() {
      updateStatus.complete(with: .failure(CancellationError()))
    }

  }

  public var name: String {
    "mcp__\(serverName.sanitized)__\(wrappedTool.name.sanitized)"
  }

  public var externalName: String {
    wrappedTool.name
  }

  public var description: String {
    wrappedTool.description ?? ""
  }

  public var inputSchema: JSON {
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

  public var displayName: String {
    "\(serverName):\(wrappedTool.name) (MCP)"
  }

  public var shortDescription: String {
    description
  }

  public func isAvailable(in mode: ChatMode) -> Bool {
    isReadonly ? true : mode == .agent
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
    let allowedCharacters = CharacterSet.alphanumerics

    // First handle camelCase to snake_case conversion
    let camelToSnake = self
      // Insert underscore between lowercase and uppercase
      .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1_$2", options: .regularExpression)
      // Insert underscore between digit and uppercase
      .replacingOccurrences(of: "([0-9])([A-Z])", with: "$1_$2", options: .regularExpression)
      // Handle consecutive uppercase letters followed by lowercase
      .replacingOccurrences(of: "([A-Z])([A-Z][a-z])", with: "$1_$2", options: .regularExpression)
      .lowercased()

    // Replace disallowed characters with underscores, then clean up
    var result = ""
    for char in camelToSnake {
      if allowedCharacters.contains(char.unicodeScalars.first!) {
        result.append(char)
      } else {
        result.append(" ")
      }
    }
    result = result
      .trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "_")
      // Collapse multiple underscores into one
      .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)

    return result
  }
}
