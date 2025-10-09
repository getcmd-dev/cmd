// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppEventServiceInterface
import AppFoundation
import ChatFeatureInterface
import ChatFoundation
import ChatServiceInterface
import CheckpointServiceInterface
import Combine
import ConcurrencyFoundation
import Dependencies
import ExtensionEventsInterface
import Foundation
import FoundationInterfaces
import JSONFoundation
import LLMFoundation
import LLMServiceInterface
import LocalServerServiceInterface
import LoggingServiceInterface
import Observation
import SettingsServiceInterface
import SharedValuesFoundation
import ThreadSafe
import ToolFoundation
import XcodeObserverServiceInterface

// TODO: look at possible retention issue of `ChatThreadViewModel`
// while making sure it is not release while streaming.

// MARK: - ChatThreadViewModel

@MainActor @Observable
final class ChatThreadViewModel: Identifiable, Equatable {

  #if DEBUG
  convenience init(name: String? = nil, messages: [ChatMessageViewModel] = []) {
    self.init(
      id: UUID(),
      name: name,
      messages: messages)
  }
  #endif

  convenience init(id: UUID? = nil) {
    self.init(
      id: id ?? UUID(),
      name: nil,
      messages: [])
  }

  init(
    id: UUID,
    name: String?,
    messages: [ChatMessageViewModel],
    events: [ChatEvent]? = nil,
    projectInfo: SelectedProjectInfo? = nil,
    knownFilesContent: [String: String] = [:],
    createdAt: Date = Date())
  {
    @Dependency(\.toolsPlugin) var toolsPlugin
    @Dependency(\.settingsService) var settingsService
    @Dependency(\.llmService) var llmService
    @Dependency(\.xcodeObserver) var xcodeObserver
    @Dependency(\.fileManager) var fileManager
    @Dependency(\.checkpointService) var checkpointService

    self.toolsPlugin = toolsPlugin
    self.settingsService = settingsService
    self.llmService = llmService
    self.xcodeObserver = xcodeObserver
    self.fileManager = fileManager
    self.checkpointService = checkpointService
    self.id = id
    self.name = name
    self.messages = messages
    self.projectInfo = projectInfo
    self.createdAt = createdAt
    context = ChatThreadContext(knownFilesContent: knownFilesContent)
    self.events = events ?? messages.flatMap { message in
      message.content.map { .message(.init(content: $0, role: message.role)) }
    }

    @Dependency(\.chatHistoryService) var chatHistoryService
    self.chatHistoryService = chatHistoryService

    input = ChatInputViewModel()
    input.didTapSendMessage = { [weak self] in Task { await self?.sendMessage() } }
    input.didCancelMessage = { [weak self] in self?.cancelCurrentMessage() }

    setUp()
  }

  typealias SelectedProjectInfo = ChatThreadModel.SelectedProjectInfo

  let id: UUID
  let createdAt: Date
  var events: [ChatEvent]
  var input: ChatInputViewModel
  // TODO: look at making this a private(set). It's needed for a finding, that ideally would be readonly
  var isStreamingResponse = false
  var hasSomeModelsAvailable = true

  private(set) var messages = [ChatMessageViewModel]()

  private(set) var projectInfo: SelectedProjectInfo?

  private(set) var isShowingChatHistory = false

  private(set) var context: ChatThreadContext

  private(set) var name: String? {
    didSet {
      if name != oldValue {
        hasChangedSinceLastSave = true
      }
    }
  }

  nonisolated static func ==(lhs: ChatThreadViewModel, rhs: ChatThreadViewModel) -> Bool {
    lhs.id == rhs.id
  }

  func resetChangeTracking() {
    lastSavedMessageCount = messages.count
    lastSavedEventCount = events.count
    hasChangedSinceLastSave = false
  }

  @MainActor
  func cancelCurrentMessage() {
    streamingTask?.task.cancel()
    streamingTask = nil
    input.cancelAllPendingToolApprovalRequests()
    // Cancel all existing tool calls.
    for message in messages {
      for content in message.content {
        if let toolUse = content.asToolUse?.toolUse, !toolUse.hasCompleted {
          toolUse.cancel()
        }
      }
    }
  }

  func handleToggleChatHistory() {
    isShowingChatHistory.toggle()
  }

  /// Add new message content to the chat thread. Usually this is done automatically by sending the content of the input in `sendMessage`.
  /// This method can be used when sending messages received from an external source, like from Xcode AI chat.
  func add(messageContents: [ChatMessageContent], role: MessageRole) {
    let message = ChatMessageViewModel(
      content: messageContents,
      role: role)
    messages.append(message)
    for content in messageContents {
      events.append(.message(.init(content: content, role: role)))
    }
  }

  @MainActor
  func sendMessage() async {
    let projectInfo = updateProjectInfo()

    await updateFocusFileInfo()

    if let summarizationTask {
      try? await summarizationTask.value
    }

    if let streamingTask {
      defaultLogger.info("Cancelling current chat streaming task")
      streamingTask.task.cancel()
      self.streamingTask = nil
    }

    // Cancel any pending tool approvals from previous messages
    input.cancelAllPendingToolApprovalRequests()

    guard let selectedModel = input.selectedModel else {
      defaultLogger.error("not sending as no model selected")
      return
    }
    let textInput = input.textInput
    let attachments = input.attachments

    input.textInput = TextInput()
    input.attachments = []

    for attachment in attachments {
      if case .file(let fileAttachment) = attachment {
        // The entire content of the attachment is sent to the LLM.
        // We update the chat context to reflect this, so that the LLM can edit this file without having to first use the read tool.
        context.set(knownFileContent: fileAttachment.content, for: fileAttachment.path)
      }
    }

    if !textInput.string.string.isEmpty {
      // TODO: reformat the string sent to the LLM
      let messageContent = ChatMessageContent.text(ChatMessageTextContent(
        projectRoot: projectInfo?.dirPath,
        text: textInput.string.string,
        attachments: attachments))
      let userMessage = ChatMessageViewModel(
        content: [messageContent],
        role: .user)

      events.append(.message(.init(content: messageContent, role: .user)))
      messages.append(userMessage)
    }
    let messages = messages.apiFormat

    if !textInput.string.string.isEmpty, name == nil {
      Task { [weak self] in
        let conversationName = try await self?.llmService.nameConversation(firstMessage: textInput.string.string)
        guard let self else { return }
        name = conversationName
        await persistThread()
      }
    }
    Task {
      await persistThread()
    }

    // Send the message to the server and stream the response.
    let indexOfLastEventFromThisMessage = Atomic(events.count - 1)
    let taskId = UUID()
    do {
      let tools: [any Tool] = toolsPlugin.tools(for: input.mode)
      let usageInfo = Atomic<LLMUsageInfo?>(nil)

      let startTime = Date()
      defaultLogger.record(
        event: "message_sent",
        value: "initiated",
        metadata: [
          "model": selectedModel.rawValue,
          "chat_mode": input.mode.rawValue,
          "attachments_count": String(attachments.count),
          "message_length": String(textInput.string.string.count),
        ])

      let task = Task {
        async let response = try await llmService.sendMessage(
          messageHistory: messages,
          tools: tools,
          model: selectedModel,
          chatMode: input.mode,
          context: DefaultChatContext(
            project: projectInfo?.path,
            projectRoot: projectInfo?.dirPath,
            prepareToExecute: { [weak self] toolUse in await self?.handlePrepareToExecute(toolUse) },
            needsApproval: { [weak self] toolUse in await self?.needsApproval(for: toolUse) ?? true },
            requestToolApproval: { [weak self] toolUse in
              try await self?.handleToolApproval(for: toolUse)
            },
            chatMode: input.mode,
            threadId: self.id.uuidString),
          handleUpdateStream: { [weak self] newMessagesUpdates in
            Task { @MainActor [weak self] in
              guard let self else { return }
              var trackedMessages = Set<UUID>()
              for await update in newMessagesUpdates.futureUpdates {
                for newMessage in update.filter({ !trackedMessages.contains($0.id) }) {
                  trackedMessages.insert(newMessage.id)

                  let newMessageState = ChatMessageViewModel(
                    content: newMessage.content.map { $0.domainFormat(projectRoot: projectInfo?.dirPath) },
                    role: .assistant)
                  self.messages.append(newMessageState)

                  for await update in newMessage.futureUpdates {
                    // new message content was received
                    if let newContent = update.content.last {
                      var content = newMessageState.content
                      let newContent = newContent.domainFormat(projectRoot: projectInfo?.dirPath)
                      content.append(newContent)
                      events.append(.message(.init(content: newContent, role: .assistant)))
                      indexOfLastEventFromThisMessage.set(to: events.count - 1)
                      newMessageState.content = content

                      // Persistence
                      Task.detached {
                        await self.persistThread()
                      }
                      if let toolUse = newContent.asToolUse?.toolUse {
                        Task.detached { [weak self] in
                          for await _ in toolUse.futureUpdates {
                            await self?.persistThread()
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          })

        let res = try await response
        usageInfo.set(to: res.usageInfo)

        recordEventAfterReceiving(messages: res.newMessages, startTime: startTime)
      }
      streamingTask = (task: task, id: taskId)

      try await task.value
      streamingTask = nil

      // Save the conversation after successful completion
      await persistThread()

      if let usageInfo = usageInfo.value {
        do {
          try await handle(usageInfo: usageInfo, model: selectedModel)
        } catch {
          defaultLogger.error("Failed to handle usage info", error)
        }
      }
    } catch {
      defaultLogger.error("Error sending message", error)
      if streamingTask?.id == taskId {
        streamingTask = nil
      }

      let lastMessageIndex = indexOfLastEventFromThisMessage.value
      if case .message(let lastEvent) = events[lastMessageIndex] {
        if error is CancellationError {
          events[lastMessageIndex] = .message(lastEvent.with(info: .init(info: "Cancelled", level: .info)))
        } else {
          events[lastMessageIndex] = .message(lastEvent.with(info: .init(
            info: "Error sending message: \(error.localizedDescription)",
            level: .error)))
        }
      }

      // Save even after error to preserve the failure state
      await persistThread()
    }
  }

  func handleRestore(checkpoint: Checkpoint) {
    Task {
      do {
        try await checkpointService.restore(checkpoint: checkpoint)
      } catch {
        defaultLogger.error("Failed to restore checkpoint", error)
      }
    }
  }

  /// Persist the current chat thread to the chat history service, so that it can be reloaded at the next app launch.
  func persistThread() async {
    // Check if there are any changes to save
    let hasNewMessages = messages.count > lastSavedMessageCount
    let hasNewEvents = events.count > lastSavedEventCount

    if !hasChangedSinceLastSave, !hasNewMessages, !hasNewEvents {
      // No changes to save
      return
    }

    do {
      let persistentTab = persistentModel

      // Save the complete tab with all resolved relationships
      try await chatHistoryService.save(chatThread: persistentTab)

      // Update tracking variables
      lastSavedMessageCount = messages.count
      lastSavedEventCount = events.count
      hasChangedSinceLastSave = false
    } catch {
      defaultLogger.error("Failed to save chat tab: \(name ?? "unnamed")", error)
    }
  }

  // MARK: - Persistence Methods

  private let chatHistoryService: ChatHistoryService

  // MARK: - Change Tracking

  private var lastSavedMessageCount = 0
  private var lastSavedEventCount = 0
  /// Whether the chat thread has new changes to save.
  private var hasChangedSinceLastSave = true

  @ObservationIgnored private var workspaceRootObservation: AnyCancellable?
  private let toolsPlugin: ToolsPlugin
  private let settingsService: SettingsService
  private let llmService: LLMService

  private let xcodeObserver: XcodeObserver
  private let fileManager: FileManagerI
  private let checkpointService: CheckpointService

  @ObservationIgnored private var cancellables = Set<AnyCancellable>()

  private var summarizationTask: Task<Void, any Error>? = nil

  /// Track the last focused file in Xcode to provide context
  private var lastFocusedFileURL: URL? = nil

  private var streamingTask: (task: Task<Void, any Error>, id: UUID)? = nil {
    didSet {
      isStreamingResponse = streamingTask != nil
    }
  }

  private func updateFocusFileInfo() async {
    // Check if the focused file in Xcode has changed and add it as context
    if let currentFocusedFile = await xcodeObserver.focusedTabURL {
      if currentFocusedFile != lastFocusedFileURL {
        lastFocusedFileURL = currentFocusedFile

        // Create an internal message to provide context about the focused file
        let focusedFileMessage = "The file currently focused in the editor is: \(currentFocusedFile.path)"
        let contextMessage = ChatMessageTextContent(
          projectRoot: projectInfo?.dirPath,
          text: focusedFileMessage,
          attachments: [])

        let focusedFileContent = ChatMessageContent.nonUserFacingText(contextMessage)
        messages.append(ChatMessageViewModel(
          content: [focusedFileContent],
          role: .user))
        events.append(.message(.init(content: focusedFileContent, role: .user)))
      }
    }
  }

  private func handle(appEvent: AppEvent) async -> Bool {
    switch appEvent {
    case let event as ExecuteExtensionRequestEvent:
      if event.command == "set_conversation_name" {
        do {
          let params = try JSONDecoder().decode(ExtensionRequest<Schema.NameConversationCommandParams>.self, from: event.data)
            .input
          if params.threadId == id.uuidString {
            name = params.name
            await persistThread()
            return true
          }
        } catch {
          defaultLogger.error("Failed to handle app event", error)
        }
      }
      break

    default:
      break
    }
    return false
  }

  private func setUp() {
    workspaceRootObservation = xcodeObserver.statePublisher.sink { @Sendable [weak self] state in
      guard state.focusedWorkspace != nil else { return }
      Task { @MainActor in
        guard let self else { return }
        _ = self.updateProjectInfo()
        self.workspaceRootObservation = nil
      }
    }

    llmService.activeModels.sink { @Sendable [weak self] activeModels in
      Task { @MainActor in
        self?.hasSomeModelsAvailable = !activeModels.isEmpty
      }
    }.store(in: &cancellables)

    context.handle(requestPersistence: { [weak self] in
      Task { await self?.persistThread() }
    })

    @Dependency(\.chatContextRegistry) var chatContextRegistry
    chatContextRegistry.register(context: context, for: id.uuidString)

    @Dependency(\.appEventHandlerRegistry) var appEventHandlerRegistry
    appEventHandlerRegistry.registerHandler { [weak self] event in
      await self?.handle(appEvent: event) ?? false
    }
  }

  private func recordEventAfterReceiving(messages: [AssistantMessage], startTime: Date) {
    let (reasoningContent, textContent, toolContent) = messages.reduce(into: (0, 0, 0)) { acc, message in
      for content in message.content {
        switch content {
        case .reasoning:
          acc.0 += 1
        case .text:
          acc.1 += 1
        case .tool:
          acc.2 += 1
        case .internalContent: break
        }
      }
    }

    defaultLogger.record(
      event: "message_sent",
      value: "completed",
      metadata: [
        "duration": String(describing: Date().timeIntervalSince(startTime)),
        "assistant_messages_count": String(describing: messages.count),
        "reasoning_content_count": String(describing: reasoningContent),
        "text_content_count": String(describing: textContent),
        "tools_count_count": String(describing: toolContent),
      ])
  }

  private func handle(usageInfo: LLMUsageInfo, model: AIModel) async throws {
    // Handle usage info, including if the conversation needs compatcing
    if usageInfo.inputTokens + usageInfo.outputTokens > Int(Float(model.contextSize) * 0.8) {
      defaultLogger.log("Summarizing conversation")

      summarizationTask = Task {
        let conversationSummary = try await llmService.summarizeConversation(
          messageHistory: messages.apiFormat,
          model: model)
        messages.append(.init(content: [.conversationSummary(.init(
          projectRoot: nil,
          deltas: [conversationSummary],
          attachments: []))], role: .user))
      }
      try await summarizationTask?.value
      summarizationTask = nil
    }
  }

  /// Whether the tool use needs to be approved by the user.
  private func needsApproval(for toolUse: any ToolUse) -> Bool {
    !shouldAlwaysApprove(toolName: toolUse.toolName)
  }

  private func handleToolApproval(for toolUse: any ToolUse) async throws {
    // Check if user has already approved this tool type
    if shouldAlwaysApprove(toolName: toolUse.toolName) {
      return // Skip approval for this tool
    }

    let approvalResult = await input.requestApproval(
      for: toolUse)

    switch approvalResult {
    case .denied:
      let reason = input.textInput.string.string
      input.textInput = TextInput() // Clear input after denial
      throw LLMServiceError.toolUsageDenied(reason: reason)

    case .approved:
      break // Continue execution
    case .alwaysApprove:
      // Store preference and continue
      storeAlwaysApprovePreference(for: toolUse.toolName)

    case .cancelled:
      throw CancellationError()
    }
  }

  private func handlePrepareToExecute(_ toolUse: any ToolUse) async {
    guard let projectInfo = updateProjectInfo() else {
      return
    }
    do {
      // Create checkpoint and add it to events before the tool call is executed.
      let checkpoint = try await checkpointService.createCheckpoint(
        projectRoot: projectInfo.dirPath,
        taskId: id.uuidString,
        message: "checkpoint")
      if !events.compactMap(\.checkpoint).contains(where: { $0.id == checkpoint.id }) {
        // Execute on the main actor to update the UI
        await MainActor.run {
          // Find the index of the last message to insert the checkpoint after it
          if
            let toolUseIndex = events
              .firstIndex(where: { $0.message?.content.asToolUse?.toolUse.toolUseId == toolUse.toolUseId })
          {
            // Insert the checkpoint before the toolUse:
            // The tool use is created first, because we might need to get permissions before doing anything else.
            // The checkpoint is created after permissions are granted and before the tool runs.
            // Semantically, the checkpoint happens "before" the tool use (ie before it runs which is the important part)
            // so once a checkpoint is created we need to re-order the events.
            events.insert(.checkpoint(checkpoint), at: toolUseIndex)
          } else if let lastMessageIndex = events.lastIndex(where: { $0.message != nil }) {
            // Insert the checkpoint after the last message
            events.insert(.checkpoint(checkpoint), at: lastMessageIndex + 1)
          } else {
            // Fallback if no messages found
            events.append(.checkpoint(checkpoint))
          }
        }
      }
      await persistThread()
    } catch {
      defaultLogger.error("Failed to create checkpoint", error)
    }
  }

  private func storeAlwaysApprovePreference(for toolName: String) {
    var currentSettings = settingsService.values()
    currentSettings.setToolPreference(toolName: toolName, alwaysApprove: true)
    settingsService.update(to: currentSettings)
  }

  private func shouldAlwaysApprove(toolName: String) -> Bool {
    settingsService.values().shouldAlwaysApprove(toolName: toolName)
  }

  private func updateProjectInfo() -> SelectedProjectInfo? {
    if let projectInfo {
      return projectInfo
    }
    if let workspace = xcodeObserver.state.focusedWorkspace {
      let projectRoot = fileManager.isDirectory(at: workspace.url) ? workspace.url.deletingLastPathComponent() : workspace.url

      Task {
        do {
          let workspaceContextMessage = try await createContextMessage(for: workspace, projectRoot: projectRoot)
          messages.append(.init(content: [.nonUserFacingText(workspaceContextMessage)], role: .user))
        } catch {
          defaultLogger.error("Failed to create context message for workspace", error)
        }
      }
      let projectInfo = SelectedProjectInfo(path: workspace.url, dirPath: projectRoot)
      self.projectInfo = projectInfo
      return projectInfo
    }
    return nil
  }

}

// MARK: - ChatEvent

enum ChatEvent: Identifiable {
  case message(_ message: ChatMessageContentWithRole)
  case checkpoint(_ checkpoint: Checkpoint)

  var message: ChatMessageContentWithRole? {
    if case .message(let message) = self {
      return message
    }
    return nil
  }

  var checkpoint: Checkpoint? {
    if case .checkpoint(let checkpoint) = self {
      return checkpoint
    }
    return nil
  }

  var id: String {
    switch self {
    case .message(let message):
      message.id.uuidString
    case .checkpoint(let checkpoint):
      checkpoint.id
    }
  }
}

extension ChatThreadViewModel.SelectedProjectInfo {
  /// Whether the project is a Swift package
  var isSwiftPackage: Bool {
    dirPath != path
  }
}
