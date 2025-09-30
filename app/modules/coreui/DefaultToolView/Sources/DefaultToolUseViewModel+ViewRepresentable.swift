// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import JSONFoundation
import Observation
import SwiftUI
import ToolFoundation

// MARK: ViewRepresentable, StreamRepresentable

extension DefaultToolUseViewModel: ViewRepresentable, StreamRepresentable {
  @MainActor
  public var body: AnyView { AnyView(DefaultToolUseView(toolUse: self)) }

  @MainActor
  public var streamRepresentation: String? {
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
