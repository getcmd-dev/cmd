// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Observation
import SwiftUI
import ToolFoundation

// MARK: - ToolUseViewModel

@Observable
@MainActor
final class ToolUseViewModel {

  init(
    toolName: String,
    status: UnknownTool.Use.Status,
    input: UnknownTool.Use.Input)
  {
    self.toolName = toolName
    self.status = status.value
    self.input = input
    Task {
      for await status in status.futureUpdates {
        self.status = status
      }
    }
  }

  let toolName: String
  let input: UnknownTool.Use.Input
  private(set) var status: ToolUseExecutionStatus<UnknownTool.Use.Output>
}

// MARK: ViewRepresentable, StreamRepresentable

extension ToolUseViewModel: ViewRepresentable, StreamRepresentable {
  @MainActor
  var body: AnyView { AnyView(ToolUseView(toolUse: self)) }

  @MainActor
  var streamRepresentation: String? {
    guard case .completed(let result) = status else { return nil }
    switch result {
    case .success(let output):
      return """
        ⏺ \(toolName)
          ⎿ Success: \(output))


        """

    case .failure(let error):
      return """
        ⏺ \(toolName)
          ⎿ Failed: \(error.localizedDescription)


        """
    }
  }
}
