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
    status: CurrentValueStream<ToolUseExecutionStatus<JSON.Value>>,
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
  public private(set) var status: ToolUseExecutionStatus<String?>
}

extension ToolUseExecutionStatus {
  func map<MappedOutput: Codable & Sendable>(_ map: (Output) -> MappedOutput) -> ToolUseExecutionStatus<MappedOutput> {
    switch self {
    case .pendingApproval:
      .pendingApproval
    case .approvalRejected(let reason):
      .approvalRejected(reason: reason)
    case .notStarted:
      .notStarted
    case .running:
      .running
    case .completed(.success(let output)):
      .completed(.success(map(output)))
    case .completed(.failure(let error)):
      .completed(.failure(error))
    }
  }
}
