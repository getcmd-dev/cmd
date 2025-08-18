// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Observation
import SwiftUI
import ToolFoundation

// MARK: - ToolUseViewModel

@Observable
@MainActor
final class ToolUseViewModel {

  init(status: LSTool.Use.Status, directoryPath: URL, projectRoot: URL?) {
    self.status = status.value
    self.directoryPath = directoryPath
    directoryDisplayPath = projectRoot.map { directoryPath.pathRelative(to: $0) } ?? directoryPath.path
    Task {
      for await status in status.futureUpdates {
        self.status = status
      }
    }
  }

  let directoryPath: URL
  let directoryDisplayPath: String
  var status: ToolUseExecutionStatus<LSTool.Use.Output>
}

// MARK: ViewRepresentable, StreamRepresentable

extension ToolUseViewModel: ViewRepresentable, StreamRepresentable {
  @MainActor
  var body: AnyView { AnyView(ToolUseView(viewModel: self)) }

  @MainActor
  var streamRepresentation: String? {
    guard case .completed(let result) = status else { return nil }
    switch result {
    case .success(let output):
      return """
        ⏺ List(\(directoryDisplayPath))
          ⎿ Listed \(output.files.count) paths


        """

    case .failure(let error):
      return """
        ⏺ List(\(directoryDisplayPath))
          ⎿ Failed: \(error.localizedDescription)


        """
    }
  }
}
