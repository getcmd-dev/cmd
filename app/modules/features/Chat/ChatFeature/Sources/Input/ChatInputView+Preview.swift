// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import LLMFoundation
import SwiftUI
import ToolFoundation

#if DEBUG
extension ChatInputViewModel {
  func withApproval(for toolUse: any ToolUse) -> ChatInputViewModel {
    Task {
      _ = await self.requestApproval(for: toolUse)
    }
    return self
  }
}

#Preview("Waiting for permission", traits: .sizeThatFitsLayout) {
  ChatInputView(
    inputViewModel: ChatInputViewModel(activeModels: AIModel.allTestCases, mode: .ask)
      .withApproval(for: TestTool().use()),
    isStreamingResponse: .constant(false))
    .frame(minHeight: 300)
}

#Preview("Ask mode") {
  ChatInputView(
    inputViewModel: ChatInputViewModel(activeModels: AIModel.allTestCases, mode: .ask),
    isStreamingResponse: .constant(false))
}

#Preview("Agent mode") {
  ChatInputView(
    inputViewModel: ChatInputViewModel(
      activeModels: AIModel.allTestCases,
      mode: .agent),
    isStreamingResponse: .constant(false))
}

#Preview("streaming") {
  ChatInputView(
    inputViewModel: .init(activeModels: AIModel.allTestCases),
    isStreamingResponse: .constant(true))
}
#endif
