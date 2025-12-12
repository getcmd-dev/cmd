// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppFoundation
import ChatFoundation
import ChatHistoryServiceInterface
import ChatInput
import Dependencies
import FileDiffFoundation
import FileDiffTypesFoundation
import Foundation
import JSONFoundation
import LLMFoundation
import LLMServiceInterface
import LocalServerServiceInterface
import LoggingServiceInterface
import Observation
import ToolFoundation
import XcodeControllerServiceInterface
import XcodeObserverServiceInterface

// MARK: - InlineChatViewModel

@Observable @MainActor
final class InlineChatViewModel {
  init(workspace: URL, editor: AnyAXUIElement, file: URL, selection: CursorRange, content: String) {
    @Dependency(\.llmService) var llmService
    self.llmService = llmService
    @Dependency(\.xcodeController) var xcodeController
    self.xcodeController = xcodeController

    self.workspace = workspace
    self.editor = editor
    self.file = file
    self.selection = selection
    originalContent = content
    self.content = content
    let input = ChatInputViewModel()
    self.input = input
    input.didTapSendMessage = { [weak self] text, attachments in
      Task {
        await self?.handleSendMessage(text: text.string.string, attachments: attachments)
      }
    }
    input.didCancelMessage = { [weak self] _ in
      self?.cancelCurrentMessage()
    }
  }

  let input: ChatInputViewModel
  let id = UUID()
  let editor: AnyAXUIElement
  let workspace: URL
  let file: URL
  let selection: CursorRange
  var model: AIModel?
  let originalContent: String
  var content: String
  var isProcessing = false
  var error: String?

  private let llmService: LLMService
  private let xcodeController: XcodeController

  private var currentTask: Task<Void, Never>?

  private func handleSendMessage(text: String, attachments _: [AttachmentModel]) async {
    guard !isProcessing else { return }
    isProcessing = true
    error = nil

    currentTask = Task {
      do {
        // Get the AI model to use
        guard let model = input.selectedModel ?? llmService.activeModels.value.first else {
          throw AppError(message: "No AI model available")
        }

        let tool = EditCurrentFileTool(oldContent: self.content)
        // Build the system prompt that instructs the AI to use the tool
        let systemPrompt = buildSystemPrompt(tool: tool)

        // Build the user message with file context
        let userMessage = buildUserMessage(text: text, selection: selection, content: originalContent, tool: tool)

        // Create the messages for the API
        let messages: [Schema.Message] = [
          Schema.Message(role: .system, content: [.textMessage(.init(text: systemPrompt))]),
          Schema.Message(role: .user, content: [.textMessage(.init(text: userMessage))]),
        ]

        // Create a simple chat context
        let context = SimpleChatContext(fileURL: file, workspace: workspace)

        // Send the message with our tool
        let response = try await llmService.sendMessage(
          messageHistory: messages,
          tools: [tool],
          model: model,
          chatMode: .agent,
          context: context,
          handleUpdateStream: { @Sendable _ in })

        // Process the assistant's response
        try await processResponse(response: response)

      } catch is CancellationError {
        // User cancelled
        defaultLogger.log("Inline chat cancelled")
      } catch {
        self.error = error.localizedDescription
        defaultLogger.error("Error processing inline chat", error)
      }

      isProcessing = false
    }

    await currentTask?.value
  }

  private func processResponse(response: SendMessageResponse) async throws {
    // Look for tool uses in the response
    for message in response.newMessages {
      for content in message.content {
        if
          case .tool(let toolUseMessage) = content,
          let toolUse = toolUseMessage.toolUse as? EditCurrentFileTool.Use
        {
          let result = try await toolUse.output
          let diff = try FileDiff.getGitDiff(oldContent: toolUse.callingTool.oldContent, newContent: result.result)
          print("got diff diff: \(diff)")
        }
      }
    }
  }

  private func cancelCurrentMessage() {
    currentTask?.cancel()
    currentTask = nil
    isProcessing = false
  }

  private func buildSystemPrompt(tool: any Tool) -> String {
    """
    You are an AI assistant that helps developers edit code directly in their editor.
    You have access to ONE tool: \(tool.name)

    \(tool.description)

    IMPORTANT:
    - You MUST use the \(tool.name) tool to make all edits. Never output code directly.
    - The file content is provided in the user's message.
    - Make all necessary changes in a SINGLE tool call.
    - Do not output any explanatory text - only use the tool.

    Tool schema:
    \(tool.inputSchema)
    """
  }

  private func buildUserMessage(text: String, selection: CursorRange, content: String, tool: any Tool) -> String {
    let selectedText = extractSelectedText(from: content, selection: selection)

    var message = """
      File: \(file.lastPathComponent)

      Current file content:
      ```
      \(content)
      ```

      """

    if !selectedText.isEmpty {
      message += """

        Selected text (lines \(selection.start.line)-\(selection.end.line)):
        ```
        \(selectedText)
        ```

        """
    }

    message += """

      User request: \(text)

      Use the \(tool.name) tool to make the requested changes.
      """

    return message
  }

  private func extractSelectedText(from content: String, selection: CursorRange) -> String {
    let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
    guard selection.start.line >= 0, selection.end.line < lines.count else {
      return ""
    }

    let selectedLines = lines[selection.start.line ... selection.end.line]
    return selectedLines.joined(separator: "\n")
  }
}

// MARK: - SimpleChatContext

private final class SimpleChatContext: ChatContext, @unchecked Sendable {
  init(fileURL: URL, workspace: URL) {
    self.fileURL = fileURL
    self.workspace = workspace
  }

  let fileURL: URL
  let workspace: URL

  var toolExecutionContext: ToolExecutionContext {
    ToolExecutionContext(
      threadId: UUID().uuidString,
      project: workspace,
      projectRoot: workspace)
  }

  func prepareToExecute(writingToolUse _: any ToolUse) async {
    // No preparation needed for inline chat
  }

  func needsApproval(for _: any ToolUse) async -> Bool {
    // Auto-approve all tool uses in inline chat
    false
  }

  func requestApproval(for _: any ToolUse) async throws {
    // No approval needed
  }

}
