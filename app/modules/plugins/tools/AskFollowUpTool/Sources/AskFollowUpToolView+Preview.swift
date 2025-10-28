// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import SwiftUI

#if DEBUG
typealias SearchFilesStatus = AskFollowUpTool.Use.Status

#Preview {
  ScrollView {
    VStack(alignment: .leading, spacing: 10) {
      let input1 = AskFollowUpTool.Input(
        question: "Can edit this file?", followUp: [
          "Yes",
          "No",
        ])
      ToolUseView(toolUse: ToolUseViewModel(
        status: SearchFilesStatus.Just(.running(input: input1)),
        input: input1,
        selectFollowUp: { _ in }))

      let input2 = AskFollowUpTool.Input(
        question: "Can edit this file?", followUp: [
          "Yes",
          "No",
        ])
      ToolUseView(toolUse: ToolUseViewModel(
        status: SearchFilesStatus.Just(.notStarted(input: input2)),
        input: input2,
        selectFollowUp: { _ in }))

      let input3 = AskFollowUpTool.Input(
        question: "Can edit this file?", followUp: [
          "Yes",
          "No",
          "Maybe",
          "I'm not sure",
          "Try and see",
        ])
      ToolUseView(toolUse: ToolUseViewModel(
        status: SearchFilesStatus.Just(.completed(input: input3, result: .success(AskFollowUpTool.Use.Output(response: "Yes")))),
        input: input3,
        selectFollowUp: { _ in }))
    }
  }
  .frame(width: 100, height: 200)
  .padding()
}
#endif
