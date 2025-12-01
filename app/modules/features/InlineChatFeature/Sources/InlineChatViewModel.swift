// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import Foundation
import LLMFoundation
import Observation
import XcodeObserverServiceInterface

@Observable @MainActor
final class InlineChatViewModel {
  init(workspace: URL, file: URL, selection: CursorRange, content: String) {
    self.workspace = workspace
    self.file = file
    self.selection = selection
    self.content = content
  }

  let id = UUID()
  let workspace: URL
  let file: URL
  let selection: CursorRange
  var inputText = ""
  var model: AIModel?
  let content: String

}
