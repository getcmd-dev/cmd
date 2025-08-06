// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatFeatureInterface
import ConcurrencyFoundation
import Dependencies
import FoundationInterfaces
import JSONFoundation
import SwiftUI
import ToolFoundation

#if DEBUG
struct TestTool: NonStreamableTool {
  public func isAvailable(in _: ChatMode) -> Bool {
    true
  }

  struct Use: NonStreamableToolUse {
    init(
      callingTool _: TestTool,
      toolUseId _: String,
      input _: String,
      context _: ToolFoundation.ToolExecutionContext,
      internalState _: InternalState? = nil,
      initialStatus _: Status.Element?)
    {
      fatalError("not implemented")
    }

    init(input: String = "") {
      self.input = input
      callingTool = TestTool()
      status = ConcurrencyFoundation.CurrentValueStream<ToolFoundation.ToolUseExecutionStatus<String>>
        .Just(.completed(.success(input)))
      toolUseId = UUID().uuidString
    }

    public typealias InternalState = EmptyObject

    public let isReadonly = true

    let context = ToolExecutionContext()

    let input: String

    let callingTool: TestTool

    var status: CurrentValueStream<ToolUseExecutionStatus<String>>

    let toolUseId: String

    func startExecuting() { }

    func reject(reason _: String?) { }

    func cancel() { }

  }

  var inputSchema = JSON.object([:])

  var name: String { "TestTool" }
  var displayName: String { "Test Tool" }
  var description: String { "A tool for testing." }
  var shortDescription: String { description }

  func use(toolUseId _: String, input _: String, context _: ToolExecutionContext) -> Use {
    Use()
  }

  func use() -> Use {
    Use()
  }

}

let messageContentWithCode = """
  Hi try this code. I left a very long explanation for the purpose of demonstrating how very long lines get displayed.
  ```swift
  // an extremely long description of this function that simply adds two integers together, because it's a very complex operation that requires a lot of explanation.
  func add(a: Int, b: Int) -> Int {
    a + b
  }
  ```
  """

let messageContentWithCodeDiff = """
  Hi try this code.
  ```swift:/path/to/file.swift
  <<<<<<< SEARCH
  Hello, world!
  =======
  Hello, universe!
  >>>>>>> REPLACE
  ```
  """

let messageContentWithUnfinishedCode = """
   Hi try this
   ```
   func add(a: Int, b: Int) -> Int {
     a 
  """

let messageContentWithLongCode = """
  Hi try this code. It's a bit long but should work well
  ```
  // an extremely long description of this function that simply adds two integers together, because it's a very complex operation that requires a lot of explanation.
  func add(a: Int, b: Int) -> Int {
    a + b
  }
  func sub(a: Int, b: Int) -> Int {
    a - b
  }
  func mul(a: Int, b: Int) -> Int {
    a * b
  }
  func div(a: Int, b: Int) -> Int {
    a / b
  }
  func mod(a: Int, b: Int) -> Int {
    a % b
  }
  func pow(a: Int, b: Int) -> Int {
    a ** b
  }
  ```
  """

extension ChatMessageViewModel {
  /// For debug puspose only.
  /// Simulate streaming of a chat message by adding one chunk of text content at a time.
  /// Chunks are automatically generated from the desired message content.
  @MainActor
  func streamOneChunk(from desiredMessage: ChatMessageViewModel) -> Bool {
    if let (j, content) = Array(content.enumerated()).last {
      if case .text(let text) = content {
        let desiredTextContent = desiredMessage.content[j].asText!.text
        if desiredTextContent != text.text {
          // Last message content is a text that is not fully streamed. Add one chunk.
          let missingText = desiredTextContent.suffix(desiredTextContent.count - text.text.count)
          let nextChunk = missingText.prefix(5)
          text.ingest(delta: String(nextChunk))
          return true
        }
      }
    }
    // try to add new content
    let j = content.count
    if desiredMessage.content.count > j {
      if case .text(let text) = desiredMessage.content[j] {
        // Add a new text content.
        content.append(.text(ChatMessageTextContent(deltas: [], attachments: text.attachments)))
        // Add a chunk of text to the new content.
        return streamOneChunk(from: desiredMessage)
      } else {
        // Tool use etc. Add the entire content directly.
        content.append(desiredMessage.content[j])
      }
      return true
    }
    return false
  }
}

/// A helper view to simulate streaming of chat messages.
struct DebugStreamingMessage: View {

  init(message: ChatMessageViewModel) {
    self.message = message
    currentMessage = ChatMessageViewModel(content: [], role: message.role)
  }

  var body: some View {
    VStack {
      HStack {
        Button("Stream one chunk") {
          _ = currentMessage.streamOneChunk(from: message)
        }
        Button("Stream all chunks") {
          Task {
            while currentMessage.streamOneChunk(from: message) {
              try await Task.sleep(nanoseconds: 50_000_000)
            }
          }
        }
        Button("Reset") {
          currentMessage.content = []
        }
      }.padding()
      ForEach(currentMessage.content) { content in
        ChatMessageView(message: .init(content: content, role: currentMessage.role))
      }
    }
  }

  @Bindable private var currentMessage: ChatMessageViewModel

  private let message: ChatMessageViewModel
}

#Preview("Failed user message") {
  ScrollView {
    ChatMessageView(message: ChatMessageContentWithRole(
      content: .text(.init(text: "Help me!")),
      role: .user,
      info: .init(info: "No more API credits", level: .error)))
  }
  .frame(width: 400)
  .padding()
}

#Preview("Cancelled user message") {
  ScrollView {
    ChatMessageView(message: ChatMessageContentWithRole(
      content: .text(.init(text: "Help me!")),
      role: .user,
      info: .init(info: "Cancelled", level: .info)))
  }
  .frame(width: 400)
  .padding()
}

#Preview("User message with file selection") {
  ScrollView {
    ChatMessageView(message: ChatMessageContentWithRole(
      content: .text(.init(text: "What does this code do?", attachments: [
        .fileSelection(AttachmentModel.FileSelectionAttachment(
          file: AttachmentModel.FileAttachment(
            path: URL(filePath: "/Users/me/app/source.swift")!,
            content: mediumFileContent),
          startLine: 4,
          endLine: 10)),
      ])),
      role: .user))
  }
  .frame(width: 400)
  .padding()
}

#Preview("Simple assistant message") {
  ScrollView {
    ChatMessageView(message: ChatMessageContentWithRole(
      content: .text(.init(text: "Not much")),
      role: .assistant))
  }
  .frame(width: 400)
  .padding()
}

#Preview("Markdown message") {
  ScrollView {
    ChatMessageView(message: ChatMessageContentWithRole(
      content: .text(.init(text: """
        # This is some Markdown
        * This is a list item

        ## This is a subheading

        This is a paragraph with a [link](https://www.google.com).

        This is a paragraph with a ![image](https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png).

        This is a paragraph with a `code` inline.

        """)),
      role: .assistant))
  }
  .frame(width: 400)
  .padding()
}

#Preview("Message with code") {
  ScrollView {
    ChatMessageView(message: ChatMessageContentWithRole(
      content: .text(.init(text: messageContentWithCode)),
      role: .assistant))
  }
  .frame(width: 400)
  .padding()
}

#Preview("Message with code diff") {
  ScrollView {
    withDependencies({
      $0.fileManager = MockFileManager(files: [
        "/path/to/file.swift": """
          Hello, world!
          What a wonderful world!
          So lucky to be here!
          """,
      ])
    }, operation: {
      ChatMessageView(message: ChatMessageContentWithRole(
        content: .text(.init(text: messageContentWithCodeDiff)),
        role: .assistant))
    })
  }
  .frame(width: 400)
  .padding()
}

#Preview("Tool use message") {
  ScrollView {
    withDependencies({
      $0.fileManager = MockFileManager(files: [
        "/path/to/file.swift": """
          Hello, world!
          What a wonderful world!
          So lucky to be here!
          """,
      ])
    }, operation: {
      ChatMessageView(message: ChatMessageContentWithRole(
        content: .toolUse(.init(toolUse: TestTool.Use())),
        role: .assistant))
    })
  }
  .frame(width: 400)
  .padding()
}

#Preview("Message with unfinished code") {
  ScrollView {
    ChatMessageView(message: ChatMessageContentWithRole(
      content: .text(.init(text: messageContentWithUnfinishedCode)),
      role: .assistant))
  }
  .frame(width: 400)
  .padding()
}

#Preview("Streaming message") {
  ScrollView {
    DebugStreamingMessage(message: ChatMessageViewModel(
      content: [.text(.init(text: messageContentWithLongCode))],
      role: .assistant))
  }
  .frame(width: 400)
  .padding()
}

extension TestTool.Use {
  public init(from _: Decoder) throws {
    fatalError("not implemented")
  }

  public func encode(to _: Encoder) throws {
    fatalError("not implemented")
  }
}

#endif
