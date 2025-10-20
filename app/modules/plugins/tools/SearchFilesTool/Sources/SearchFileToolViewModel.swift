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
    input: SearchFilesTool.Use.Input,
    rootPath: String?)
  {
    self.status = status.value
    self.input = input
    self.rootPath = rootPath
    Task {
      for await status in status.futureUpdates {
        self.status = status
      }
    }
  }

  let input: SearchFilesTool.Use.Input
  let rootPath: String?
  var status: ToolUseExecutionStatus<SearchFilesTool.Use.Output>
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
        ⏺ Search(\(input.regex))
          ⎿ Found \(output.results.count) matches\(output.hasMore ? " (truncated)" : "")


        """

    case .failure(let error):
      return """
        ⏺ Search(\(input.regex))
          ⎿ Failed: \(error.localizedDescription)


        """
    }
  }
}
