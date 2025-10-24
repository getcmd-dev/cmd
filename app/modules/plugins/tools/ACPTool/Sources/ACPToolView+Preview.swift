// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import ToolFoundation
import ToolTypesFoundation

#if DEBUG

#Preview("All States") {
  ScrollView {
    VStack(alignment: .leading, spacing: 16) {
      // Not Started
      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.notStarted),
        input: .init(
          kind: .read,
          title: "Read file.swift"),
        projectRoot: nil))

      // Pending Approval
      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.pendingApproval),
        input: .init(
          kind: .edit,
          title: "Edit main.swift"),
        projectRoot: nil))

      // Rejected
      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.approvalRejected(reason: "Rejected")),
        input: .init(
          kind: .delete,
          title: "Delete temp.txt"),
        projectRoot: nil))

      // Running
      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.running),
        input: .init(
          kind: .execute,
          title: "swift build"),
        projectRoot: nil))

      // Completed with text content
      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.completed(.success(.init(
          kind: .read,
          content: [
            .aCPToolOutputMediaContent(.init(
              content: .aCPToolOutputMediaContentText(.init(
                text: """
                  import Foundation

                  func helloWorld() {
                      print("Hello, world!")
                  }
                  """)))),
          ])))),
        input: .init(
          kind: .read,
          title: "Read HelloWorld.swift"),
        projectRoot: nil))

      // Completed with diff
      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.completed(.success(.init(
          kind: .edit,
          content: [
            .aCPToolOutputDiff(.init(
              newText: "let version = \"2.0\"",
              oldText: "let version = \"1.0\"",
              path: "/path/to/Config.swift")),
          ])))),
        input: .init(
          kind: .edit,
          title: "Update version in Config.swift"),
        projectRoot: nil))

      // Completed with terminal
      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.completed(.success(.init(
          kind: .execute,
          content: [
            .aCPToolOutputTerminal(.init(
              terminalId: "terminal-123")),
          ])))),
        input: .init(
          kind: .execute,
          title: "swift test"),
        projectRoot: nil))

      // Error
      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.completed(.failure(NSError(
          domain: "TestError",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "File not found"])))),
        input: .init(
          kind: .read,
          title: "Read missing.swift"),
        projectRoot: nil))
    }
    .padding()
  }
  .frame(minWidth: 500, minHeight: 800)
}

#Preview("Different Tool Kinds") {
  ScrollView {
    VStack(alignment: .leading, spacing: 16) {
      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.completed(.success(.init(
          kind: .read,
          content: [
            .aCPToolOutputMediaContent(.init(
              content: .aCPToolOutputMediaContentText(.init(
                text: "File contents here...")))),
          ])))),
        input: .init(
          kind: .read,
          title: "Read file.swift"),
        projectRoot: nil))

      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.completed(.success(.init(
          kind: .edit,
          content: [
            .aCPToolOutputDiff(.init(
              newText: "new content",
              oldText: "old content",
              path: "/path/to/file.swift")),
          ])))),
        input: .init(
          kind: .edit,
          title: "Edit file.swift"),
        projectRoot: nil))

      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.running),
        input: .init(
          kind: .search,
          title: "Search for 'TODO'"),
        projectRoot: nil))

      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.running),
        input: .init(
          kind: .execute,
          title: "swift build"),
        projectRoot: nil))

      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.running),
        input: .init(
          kind: .think,
          title: "Analyzing code structure"),
        projectRoot: nil))

      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.running),
        input: .init(
          kind: .fetch,
          title: "Fetch https://api.example.com"),
        projectRoot: nil))

      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.running),
        input: .init(
          kind: .move,
          title: "Move file.swift to archive/"),
        projectRoot: nil))

      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.running),
        input: .init(
          kind: .delete,
          title: "Delete temp.txt"),
        projectRoot: nil))

      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.running),
        input: .init(
          kind: .switchMode,
          title: "Switch to plan mode"),
        projectRoot: nil))

      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.running),
        input: .init(
          kind: .other,
          title: "Custom tool action"),
        projectRoot: nil))
    }
    .padding()
  }
  .frame(minWidth: 500, minHeight: 800)
}

#Preview("Complex Content") {
  ScrollView {
    VStack(alignment: .leading, spacing: 16) {
      // Multiple content items
      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.completed(.success(.init(
          kind: .edit,
          content: [
            .aCPToolOutputMediaContent(.init(
              content: .aCPToolOutputMediaContentText(.init(
                text: "Modified 3 files successfully")))),
            .aCPToolOutputDiff(.init(
              newText: "let version = \"2.0\"",
              oldText: "let version = \"1.0\"",
              path: "/path/to/Config.swift")),
            .aCPToolOutputDiff(.init(
              newText: "import SwiftUI",
              oldText: nil,
              path: "/path/to/View.swift")),
          ])))),
        input: .init(
          kind: .edit,
          title: "Update multiple files"),
        projectRoot: nil))

      // Resource link
      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.completed(.success(.init(
          kind: .fetch,
          content: [
            .aCPToolOutputMediaContent(.init(
              content: .aCPToolOutputMediaContentResourceLink(.init(
                description: "API documentation for Swift",
                name: "Swift Docs",
                uri: "https://docs.swift.org")))),
          ])))),
        input: .init(
          kind: .fetch,
          title: "Fetch documentation"),
        projectRoot: nil))

      // Embedded resource
      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.completed(.success(.init(
          kind: .read,
          content: [
            .aCPToolOutputMediaContent(.init(
              content: .aCPToolOutputMediaContentResource(.init(
                resource: .aCPToolOutputMediaContentResourceEmbeddedResourceText(.init(
                  text: "Resource content here...",
                  uri: "file:///path/to/resource.txt")))))),
          ])))),
        input: .init(
          kind: .read,
          title: "Read resource"),
        projectRoot: nil))
    }
    .padding()
  }
  .frame(minWidth: 500, minHeight: 700)
}

#Preview("With Project Root") {
  ScrollView {
    VStack(alignment: .leading, spacing: 16) {
      ToolUseView(toolUse: ToolUseViewModel(
        status: .Just(.completed(.success(.init(
          kind: .read,
          content: [
            .aCPToolOutputMediaContent(.init(
              content: .aCPToolOutputMediaContentText(.init(
                text: "File contents...")))),
          ])))),
        input: .init(
          kind: .read,
          title: "/Users/developer/projects/MyApp/Sources/Main.swift"),
        projectRoot: URL(filePath: "/Users/developer/projects/MyApp")))
    }
    .padding()
  }
  .frame(minWidth: 500, minHeight: 200)
}

#Preview("Parsing raw input") {
  ScrollView {
    VStack(alignment: .leading, spacing: 16) {
      ACPTool.use(toolName: "search", toolUseId: "search", jsonInput: """
                            {
                              "kind": "search",
                              "rawInput": {
                                "command": [
                                  "bash",
                                  "-lc",
                                  "rg \\\"folder\\\" modules/features/Chat/ChatFeature -n"
                                ],
                                "cwd": "/Users/guigui/dev/conductor/cmd/.conductor/san-marino-v1/app",
                                "parsed_cmd": [
                                  {
                                    "path": "ChatFeature",
                                    "query": "folder",
                                    "type": "search",
                                    "cmd": "rg folder modules/features/Chat/ChatFeature -n"
                                  }
                                ],
                                "call_id": "call_98AY4bp4nSZbk38jfVYMj7rc"
                              },
                              "type": "acp_tool_input",
                              "title": "Search folder in ChatFeature"
                            }
        """)
    }
    .padding()
  }
  .frame(minWidth: 500, minHeight: 200)
}

extension ACPTool {
  @MainActor
  static func use(toolName: String, toolUseId: String, jsonInput: String) -> some View {
    if let toolUse = try? use(toolName: toolName, toolUseId: toolUseId, jsonInput: jsonInput) {
      return AnyView(toolUse.viewModel.body)
    } else {
      return AnyView(Text("error"))
    }
  }

  private static func use(toolName: String, toolUseId: String, jsonInput: String) throws -> ACPTool.Use {
    let tool = ACPTool(id: toolName, referenceId: toolName, displayName: toolName)
    let data = jsonInput.utf8Data
    return try tool.use(
      toolUseId: toolUseId,
      input: data,
      context: ToolExecutionContext())
  }
}

#endif
