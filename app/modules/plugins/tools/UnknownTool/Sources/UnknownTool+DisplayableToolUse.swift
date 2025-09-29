// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ToolFoundation

extension UnknownTool.Use: DisplayableToolUse {
  @MainActor
  public var viewModel: some StreamRepresentable & ViewRepresentable {
    createViewModel()
  }

  @MainActor
  func createViewModel() -> AnyToolUseViewModel {
    AnyToolUseViewModel(ToolUseViewModel(toolName: callingTool.name, status: status, input: input))
  }

}
