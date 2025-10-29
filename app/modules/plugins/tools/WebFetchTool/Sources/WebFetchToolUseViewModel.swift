// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Observation
import SwiftUI
import ToolFoundation

// MARK: - WebFetchToolUseViewModel

@Observable
@MainActor
final class WebFetchToolUseViewModel {

  init(status: WebFetchTool.Use.Status, input: WebFetchTool.Use.Input) {
    self.status = status.value
    self.input = input
    Task { [weak self] in
      for await status in status.futureUpdates {
        self?.status = status
      }
    }
  }

  let input: WebFetchTool.Use.Input
  var status: ToolUseExecutionStatus<WebFetchTool.Use.Output>
}

// MARK: ViewRepresentable, StreamRepresentable

extension WebFetchToolUseViewModel: ViewRepresentable, StreamRepresentable {
  @MainActor
  var body: AnyView { AnyView(WebFetchToolUseView(toolUse: self)) }

  @MainActor
  var streamRepresentation: String? {
    guard case .completed(let result) = status else { return nil }
    switch result {
    case .success:
      return """
        ⏺ WebFetch(\(input.url))
          ⎿ Content fetched and processed


        """

    case .failure(let error):
      return """
        ⏺ WebFetch(\(input.url))
          ⎿ Failed: \(error.localizedDescription)


        """
    }
  }
}
