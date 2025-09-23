// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation

private let toolsPluginKey = CodingUserInfoKey(rawValue: "toolsPlugin")!

extension Tool {

  func decode<K: CodingKey>(from container: KeyedDecodingContainer<K>, forKey key: K) throws -> Use {
    try container.decode(Use.self, forKey: key)
  }

}

extension ToolUse {

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: ToolUseCodingKeys.self)

    let callingTool = try container.decode(SomeTool.self, forKey: .callingTool)
    let toolUseId = try container.decode(String.self, forKey: .toolUseId)
    let input = try container.decode(Input.self, forKey: .input)
    let context = try container.decode(ToolExecutionContext.self, forKey: .context)
    let internalState = try container.decodeIfPresent(InternalState.self, forKey: .internalState)
    let statusValue = try container.decode(ToolUseExecutionStatus<Output>.self, forKey: .status)
    let isInputComplete = try container.decode(Bool.self, forKey: .isInputComplete)

    self.init(
      callingTool: callingTool,
      toolUseId: toolUseId,
      input: input,
      isInputComplete: isInputComplete,
      context: context,
      internalState: internalState,
      initialStatus: statusValue)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: ToolUseCodingKeys.self)

    try container.encode(callingTool, forKey: .callingTool)
    try container.encode(toolUseId, forKey: .toolUseId)
    try container.encode(input, forKey: .input)
    try container.encode(context, forKey: .context)
    try container.encode(internalState, forKey: .internalState)
    try container.encode(status.value, forKey: .status)
    try container.encode(isInputComplete, forKey: .isInputComplete)
  }
}

private enum ToolUseCodingKeys: String, CodingKey {
  case callingTool
  case toolUseId
  case input
  case context
  case internalState
  case status
  case isInputComplete
}

extension KeyedDecodingContainer {
  /// Decodes an array, dropping values that failed to decode.
  /// This can be useful to decode streamed input, where the last value in the array was truncated in a way that makes decoding impossible.
  public func resilientlyDecode<T: Decodable>(_: [T].Type, forKey key: K) throws -> [T] {
    var items = [T?]()
    var container = try nestedUnkeyedContainer(forKey: key)
    while !container.isAtEnd, items.count < container.count ?? Int.max {
      items.append(try? container.decode(T.self))
    }
    return items.compactMap(\.self)
  }

  /// Decodes the use of a given tool from the container.
  public func decode<T: Tool>(useOf tool: T, forKey: K) throws -> T.Use {
    try tool.decode(from: self, forKey: forKey)
  }

  public func decode<T: Tool>(_: T.Type, forKey key: K) throws -> T {
    guard let tool = try decodeAnyTool(forKey: key) as? T else {
      throw DecodingError.dataCorruptedError(
        forKey: key,
        in: self,
        debugDescription: "Tool does't match the expected type \(T.self)")
    }
    return tool
  }

  public func decodeAnyTool(forKey key: K) throws -> any Tool {
    let toolName = try decode(String.self, forKey: key)
    guard let toolsPlugin = try superDecoder().userInfo[toolsPluginKey] as? ToolsPlugin else {
      throw DecodingError.dataCorruptedError(
        forKey: key,
        in: self,
        debugDescription: "The tools plugin was not set in the decoder. Make sure to call `decoder.userInfo.set(toolPlugin:)` before decoding tools.")
    }
    guard let tool = toolsPlugin.tool(named: toolName) else {
      throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Tool \(toolName) not found")
    }
    return tool
  }
}

extension KeyedEncodingContainer {
  public mutating func encode(_ tool: some Tool, forKey key: K) throws {
    try encode(tool.name, forKey: key)
  }
}

extension [CodingUserInfoKey: Any] {
  public mutating func set(toolPlugin: ToolsPlugin) {
    self[toolsPluginKey] = toolPlugin
  }
}

extension StreamableInput: Codable {

  public init(from decoder: any Decoder) throws {
    /// When working with streamed input,
    self = try .streaming(StreamingInput(from: decoder))
  }

  public func encode(to encoder: any Encoder) throws {
    switch self {
    case .streaming(let input):
      try input.encode(to: encoder)
    case .streamed(let input):
      try input.encode(to: encoder)
    }
  }
}

extension ToolUseExecutionStatus: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let status = try container.decode(String.self, forKey: .status)
    switch status {
    case "pendingApproval":
      self = .pendingApproval

    case "notStarted":
      self = .notStarted

    case "running":
      self = .running

    case "rejected":
      let reason = try container.decode(String?.self, forKey: .value)
      self = .approvalRejected(reason: reason)

    case "completed":
      let result = try container.decode(Result<Output, Error>.self, forKey: .value)
      self = .completed(result)

    default:
      throw DecodingError.dataCorruptedError(
        forKey: .status,
        in: container,
        debugDescription: "Unknown status value: \(status)")
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .pendingApproval:
      try container.encode("pendingApproval", forKey: .status)

    case .notStarted:
      try container.encode("notStarted", forKey: .status)

    case .running:
      try container.encode("running", forKey: .status)

    case .approvalRejected(reason: let reason):
      try container.encode("rejected", forKey: .status)
      try container.encode(reason, forKey: .value)

    case .completed(let result):
      try container.encode("completed", forKey: .status)
      try container.encode(result, forKey: .value)
    }
  }

  private enum CodingKeys: String, CodingKey {
    case status
    case value
  }
}

extension Result: Codable where Success: Codable, Failure == Error {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    switch type {
    case "success":
      let value = try container.decode(Success.self, forKey: .value)
      self = .success(value)

    case "failure":
      let errorDescription = try container.decode(String.self, forKey: .value)
      let error = AppError(message: errorDescription)
      self = .failure(error)

    default:
      throw DecodingError.dataCorruptedError(
        forKey: .type,
        in: container,
        debugDescription: "Unknown result type: \(type)")
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .success(let value):
      try container.encode("success", forKey: .type)
      try container.encode(value, forKey: .value)

    case .failure(let error):
      try container.encode("failure", forKey: .type)
      try container.encode(error.localizedDescription, forKey: .value)
    }
  }

  private enum CodingKeys: String, CodingKey {
    case type
    case value
  }
}
