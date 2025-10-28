// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import JSONFoundation
import Observation

// MARK: - DefaultToolUseViewModel

@Observable
@MainActor
public final class DefaultToolUseViewModel {

  public init(
    toolName: String,
    status: CurrentValueStream<ToolUseExecutionStatus<JSON.Value, JSON.Value>>,
    input: JSON.Value)
  {
    self.toolName = toolName
    self.status = status.value.map(\.prettyPrintedString)
    self.input = input.prettyPrintedString
    Task {
      for await status in status.futureUpdates {
        self.status = status.map(\.prettyPrintedString)
      }
    }
  }

  public let toolName: String
  public let input: String?
  public private(set) var status: ToolUseExecutionStatus<JSON.Value, String?>
}

extension ToolUseExecutionStatus {
  func map<MappedOutput: Codable & Sendable>(_ map: (Output) -> MappedOutput) -> ToolUseExecutionStatus<Input, MappedOutput> {
    switch self {
    case .pendingApproval(let input):
      .pendingApproval(input: input)
    case .approvalRejected(let input, let reason):
      .approvalRejected(input: input, reason: reason)
    case .notStarted(let input):
      .notStarted(input: input)
    case .running(let input):
      .running(input: input)
    case .completed(let input, .success(let output)):
      .completed(input: input, result: .success(map(output)))
    case .completed(let input, .failure(let error)):
      .completed(input: input, result: .failure(error))
    case .failedToDecode(let error):
      .failedToDecode(error: error)
    }
  }

  public func mapInput<MappedInput: Codable & Sendable>(_ mapInput: (Input) -> MappedInput) -> ToolUseExecutionStatus<MappedInput, Output> {
    switch self {
    case .pendingApproval(let input):
      .pendingApproval(input: mapInput(input))
    case .approvalRejected(let input, let reason):
      .approvalRejected(input: mapInput(input), reason: reason)
    case .notStarted(let input):
      .notStarted(input: mapInput(input))
    case .running(let input):
      .running(input: mapInput(input))
    case .completed(let input, let result):
      .completed(input: mapInput(input), result: result)
    case .failedToDecode(let error):
      .failedToDecode(error: error)
    }
  }
}
