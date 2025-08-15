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
    status: SearchFilesTool.Use.Status,
    input: SearchFilesTool.Use.Input)
  {
    self.status = status.value
    self.input = input
    Task {
      for await status in status {
        self.status = status
      }
    }
  }

  let input: SearchFilesTool.Use.Input
  var status: ToolUseExecutionStatus<SearchFilesTool.Use.Output>
}

// MARK: ViewRepresentable, StreamRepresentable

extension ToolUseViewModel: ViewRepresentable, StreamRepresentable {
  @MainActor
  var body: AnyView { AnyView(ToolUseView(toolUse: self)) }

  @MainActor
  var streamRepresentation: String? { nil }
}
