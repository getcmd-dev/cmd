// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@MainActor
public final class CodeCompletionWindowsManager: Sendable {
  public init() {
    codeCompletionWindow = CodeCompletionWindow()
    codeCompletionWindow?.show()
    codeCompletionWindow?.orderFrontRegardless()
  }

  private var codeCompletionWindow: CodeCompletionWindow?
}
