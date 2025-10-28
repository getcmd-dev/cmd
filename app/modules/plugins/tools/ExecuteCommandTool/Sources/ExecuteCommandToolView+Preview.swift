// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ConcurrencyFoundation
import SwiftUI
import ToolFoundation

#if DEBUG
extension ToolUseViewModel {
  convenience init(
    command: String,
    status: ExecuteCommandTool.Use.Status)
  {
    self.init(
      command: command,
      status: status,
      stdout: .Just(.Just(Data())),
      stderr: .Just(.Just(Data())),
      kill: { try? await Task.sleep(for: .seconds(1)) })
  }
}

#Preview {
  ScrollView {
    VStack(alignment: .leading, spacing: 10) {
      let input1 = ExecuteCommandTool.Use.Input(
        command: "ls",
        cwd: nil,
        canModifySourceFiles: false,
        canModifyDerivedFiles: false)
      ToolUseView(toolUse: ToolUseViewModel(
        command: "ls",
        status: .Just(.running(input: input1))))

      let input2 = ExecuteCommandTool.Use.Input(
        command: "ls",
        cwd: nil,
        canModifySourceFiles: false,
        canModifyDerivedFiles: false)
      ToolUseView(toolUse: ToolUseViewModel(
        command: "ls",
        status: .Just(.notStarted(input: input2))))

      let input3 = ExecuteCommandTool.Use.Input(
        command: "ls",
        cwd: nil,
        canModifySourceFiles: false,
        canModifyDerivedFiles: false)
      ToolUseView(toolUse: ToolUseViewModel(
        command: "ls",
        status: .Just(.completed(input: input3, result: .success(.init(
          output: "filePath",
          exitCode: 0)))),
        stdout: .Just(.Just(String("""
          total 0
          drwxr-xr-x@ 6 me  staff   192B Mar 26 21:41 ./
          drwxr-xr-x@ 4 me  staff   128B Mar 21 09:38 ../
          drwxr-xr-x@ 8 me  staff   256B Mar 27 15:01 ExecuteCommandTool/
          drwxr-xr-x@ 7 me  staff   224B Mar 27 15:01 LSTool/
          drwxr-xr-x@ 7 me  staff   224B Mar 27 15:01 ReadFileTool/
          drwxr-xr-x@ 7 me  staff   224B Mar 27 15:01 SearchFilesTool/
          """).utf8Data)),
        stderr: .Just(.Just(Data())),
        kill: { }))
    }
  }
  .frame(minWidth: 200, minHeight: 500)
  .padding()
}
#endif
