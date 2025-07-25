// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Observation
import ToolFoundation

// MARK: - ToolUseViewModel

@Observable
@MainActor
final class ToolUseViewModel {

  init(status: LSTool.Use.Status, directoryPath: URL) {
    self.status = status.value
    self.directoryPath = directoryPath
    Task {
      for await status in status {
        self.status = status
      }
    }
  }

  let directoryPath: URL
  var status: ToolUseExecutionStatus<LSTool.Use.Output>
}
