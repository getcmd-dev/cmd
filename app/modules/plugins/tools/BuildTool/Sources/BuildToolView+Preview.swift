// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ConcurrencyFoundation
import SwiftUI
import XcodeControllerServiceInterface

#if DEBUG
#Preview {
  ScrollView {
    VStack(alignment: .leading, spacing: 10) {
      let input1 = BuildTool.Input(for: .test)
      ToolUseView(toolUse: ToolUseViewModel(
        buildType: .test,
        status: .Just(.running(input: input1))))
      let input2 = BuildTool.Input(for: .run)
      ToolUseView(toolUse: ToolUseViewModel(
        buildType: .run,
        status: .Just(.notStarted(input: input2))))
      let input3 = BuildTool.Input(for: .run)
      ToolUseView(toolUse: ToolUseViewModel(
        buildType: .run,
        status: .Just(.completed(input: input3, result: .success(.init(
          buildResult: BuildSection(
            title: "Build Target",
            messages: [
              .init(message: "Careful with that", severity: .warning, location: nil),
              .init(message: "Build succeeded", severity: .info, location: nil),
            ],
            subSections: [],
            duration: 2.5),
          isSuccess: true))))))
      let input4 = BuildTool.Input(for: .run)
      ToolUseView(toolUse: ToolUseViewModel(
        buildType: .run,
        status: .Just(.completed(input: input4, result: .success(.init(
          buildResult: BuildSection(
            title: "Build Target",
            messages: [
              .init(message: "Oupsy", severity: .error, location: .init(
                file: URL(fileURLWithPath: "/path/to/file.swift"),
                startingLineNumber: 1,
                startingColumnNumber: 1,
                endingLineNumber: 1,
                endingColumnNumber: 14)),
              .init(message: "Careful with that", severity: .warning, location: nil),
              .init(message: "Build failed", severity: .info, location: nil),
            ],
            subSections: [],
            duration: 1.2),
          isSuccess: false))))))
      let input5 = BuildTool.Input(for: .run)
      ToolUseView(toolUse: ToolUseViewModel(
        buildType: .run,
        status: .Just(.completed(input: input5, result: .failure(AppError("Failed to build"))))))
    }
  }
  .frame(minWidth: 200, minHeight: 500)
  .padding()
}
#endif
