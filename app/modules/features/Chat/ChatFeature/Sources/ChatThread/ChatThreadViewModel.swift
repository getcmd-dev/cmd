// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatFoundation
import ChatHistoryServiceInterface
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
import SettingsServiceToolsAdapter
import SharedValuesFoundation
import ThreadSafe
import ToolFoundation
import XcodeObserverServiceInterface

// MARK: - ChatThreadViewModel
@MainActor @Observable
final class ChatThreadViewModel: Identifiable, Equatable, Sendable {

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
    inputModel: ChatInputModel? = nil,
    createdAt: Date = Date())
  {
    @Dependency(\.toolsPlugin) var toolsPlugin
    @Dependency(\.settingsService) var settingsService
    @Dependency(\.llmService) var llmService
    @Dependency(\.xcodeObserver) var xcodeObserver
    @Dependency(\.fileManager) var fileManager
    @Dependency(\.checkpointService) var checkpointService
    @Dependency(\.chatService) var chatService

    self.toolsPlugin = toolsPlugin
    self.settingsService = settingsService
    self.llmService = llmService
    self.xcodeObserver = xcodeObserver
    self.fileManager = fileManager
    self.checkpointService = checkpointService
    self.chatService = chatService
    self.id = id
    self.name = name
    self.messages = messages
    self.projectInfo = projectInfo
    self.createdAt = createdAt
    context = ChatThreadContext(knownFilesContent: knownFilesContent)
    let events = events ?? messages.flatMap { message in
      message.content.map { .message(.init(content: $0, role: message.role)) }
    }
    self.events = events

    // Initialize latestTokenUsage from events if available
    latestTokenUsage = events.lazy.compactMap(\.tokenUsage).last

    @Dependency(\.chatHistoryService) var chatHistoryService
    self.chatHistoryService = chatHistoryService

    input = ChatInputViewModel(queuedMessages: inputModel?.queuedMessages ?? [])
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

  /// The latest token usage information from the most recent message
  private(set) var latestTokenUsage: TokenUsageEvent?

  /// Whether a conversation compaction is in progress
  private(set) var isCompactingConversation = false

  /// Whether this tab has completed streaming while not being focused
  var hasUnreadCompletion = false

  /// Whether this tab is currently focused/selected
  var isFocused = false {
    didSet {
      // Clear badge when tab becomes focused
      if isFocused {
        hasUnreadCompletion = false
      }
    }
  }

  /// Whether this chat thread is empty (has no events)
  var isEmpty: Bool {
    events.isEmpty
  }

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
    // Release the strong reference and buffer for reuse when cancelling
    chatService.stopKeepingAlive(self, for: id)
    persistThread()
  }

  func handleToggleChatHistory() {
    isShowingChatHistory.toggle()
  }

  /// Manually compact the conversation by summarizing it
  @MainActor
  func compactConversation() async {
    guard summarizationTask == nil else { return }
    guard let model = input.selectedModel else { return }

    summarizationTask = Task {
      let response = try await llmService.summarizeConversation(
        messageHistory: messages.apiFormat,
        model: model)
      messages.append(.init(content: [.conversationSummary(.init(
        projectRoot: projectInfo?.dirPath,
        deltas: [response.summary],
        attachments: []))], role: .user))

      if let usageInfo = response.usageInfo {
        // In the next turn, only the response from the summarization will be sent.
        // So we update our token count only accounting for the output.
        // TODO: When we'll also track cost, the cost of the input tokens for the summarization should not be lost.
        let tokenUsageEvent = TokenUsageEvent(
          inputTokens: 0,
          cachedInputTokens: 0,
          outputTokens: usageInfo.outputTokens)
        latestTokenUsage = tokenUsageEvent
        events.append(.tokenUsage(tokenUsageEvent))
      }

      persistThread()
    }
    isCompactingConversation = true
    do {
      try await summarizationTask?.value
    } catch {
      defaultLogger.error("Failed to compact conversation", error)
    }
    summarizationTask = nil
    isCompactingConversation = false
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
      chatService.stopKeepingAlive(self, for: id)
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
      switch attachment {
      case .file(let fileAttachment):
        // The entire content of the attachment is sent to the LLM.
        // We update the chat context to reflect this, so that the LLM can edit this file without having to first use the read tool.
        context.set(knownFileContent: fileAttachment.content, for: fileAttachment.path)

      default:
        break
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

    if !textInput.string.string.isEmpty, name == nil, let selectedModel = input.selectedModel {
      let llmService = llmService
      Task { [weak self] in
        do {
          let conversationName = try await self?.llmService.prompt(
            """
            Give a title for this coding conversation in under 50 characters.\nCapture the main goal. Respond with ONLY the title, nothing else

            good output example : `Fixing the login flow`
            bad output example: `Here's a concise summary of the conversation: Fixing the login flow`
            bad output example: `This conversation is about fixing the login flow`

            Coding conversation:\n\n\(textInput.string.string)
            """,
            model: llmService.lowTierModel()?.modelInfo ?? selectedModel)
          guard let self else { return }
          name = conversationName
          persistThread()
        } catch {
          defaultLogger.error("Failed to name conversation", error)
        }
      }
    }
    persistThread()

    // Send the message to the server and stream the response.
    let indexOfLastEventFromThisMessage = Atomic(events.count - 1)
    let taskId = UUID()
    do {
      // Get the configured tools for this chat mode
      let tools = settingsService.tools(availableIn: input.mode, toolsPlugin: toolsPlugin)
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
                    hasChangedSinceLastSave = true

                    // new message content was received
                    if let newContent = update.content.last {
                      var content = newMessageState.content
                      let newContent = newContent.domainFormat(projectRoot: projectInfo?.dirPath)
                      content.append(newContent)
                      events.append(.message(.init(content: newContent, role: .assistant)))
                      indexOfLastEventFromThisMessage.set(to: events.count - 1)
                      newMessageState.content = content
                      // Persistence
                      persistThread()
                      if let toolUse = newContent.asToolUse?.toolUse {
                        Task { [weak self] in
                          for await _ in toolUse.futureUpdates {
                            self?.persistThread()
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

      // Retain self while streaming to prevent deallocation when switching tabs
      chatService.keepAlive(self, for: id)

      defaultLogger.log("ChatThreadViewModel awaiting streaming task completion")
      try await task.value
      defaultLogger.log("ChatThreadViewModel streaming task completed, setting streamingTask to nil")
      streamingTask = nil

      // Save the conversation after successful completion
      persistThread()

      // Release the strong reference and buffer for reuse after streaming and persistence are complete
      chatService.stopKeepingAlive(self, for: id)

      // Process next queued message if available
      input.processNextQueuedMessage()

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
      persistThread()

      // Release the strong reference and buffer for reuse after error handling and persistence are complete
      chatService.stopKeepingAlive(self, for: id)

      // Process next queued message if available (even after error)
      input.processNextQueuedMessage()
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
  func persistThread() {
    persistenceQueue.queue { [weak self] in
      await self?.performPersistence()
      // Add a 250ms delay after persisting to further limit CPU usage
      try? await Task.sleep(for: .milliseconds(250))
    }
  }

  /// Queue for debouncing persistence calls to limit CPU usage while ensuring the last call executes
  private let persistenceQueue = ReplaceableTaskQueue<Void>()

  // MARK: - Persistence Methods

  private let chatHistoryService: ChatHistoryService
  private let chatService: ChatService

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
      let wasStreaming = oldValue != nil
      let isStreaming = streamingTask != nil
      isStreamingResponse = isStreaming

      // When streaming completes and tab is not focused, set the badge
      if wasStreaming, !isStreaming, !isFocused {
        hasUnreadCompletion = true
      }
    }
  }

  /// Internal method that performs the actual persistence operation.
  /// This is called through the debounced queue.
  @MainActor
  private func performPersistence() async {
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
    // Store token usage event
    let tokenUsageEvent = TokenUsageEvent(
      inputTokens: usageInfo.inputTokens,
      cachedInputTokens: usageInfo.cachedInputTokens,
      outputTokens: usageInfo.outputTokens)
    latestTokenUsage = tokenUsageEvent
    events.append(.tokenUsage(tokenUsageEvent))
    persistThread()

    // Handle usage info, including if the conversation needs compatcing
    if usageInfo.inputTokens + usageInfo.outputTokens > Int(Float(model.contextSize) * 0.8) {
      defaultLogger.log("Summarizing conversation")
      await compactConversation()
    }
  }

  /// Whether the tool use needs to be approved by the user.
  /// Note: We use `toolReferenceId` (the internal tool identifier) for permission tracking,
  /// rather than the external `toolId`, to ensure that approval preferences are consistent
  /// across different representations of the same tool.
  private func needsApproval(for toolUse: any ToolUse) -> Bool {
    !shouldAlwaysApprove(toolReferenceId: toolUse.toolReferenceId)
  }

  private func handleToolApproval(for toolUse: any ToolUse) async throws {
    // Check if user has already approved this tool type
    if shouldAlwaysApprove(toolReferenceId: toolUse.toolReferenceId) {
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
      storeAlwaysApprovePreference(for: toolUse.toolReferenceId)

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
      persistThread()
    } catch {
      defaultLogger.error("Failed to create checkpoint", error)
    }
  }

  private func storeAlwaysApprovePreference(for toolReferenceId: String) {
    var currentSettings = settingsService.values()
    currentSettings.setToolPreference(toolReferenceId: toolReferenceId, alwaysApprove: true)
    settingsService.update(to: currentSettings)
  }

  private func shouldAlwaysApprove(toolReferenceId: String) -> Bool {
    settingsService.values().shouldAlwaysApprove(toolReferenceId: toolReferenceId)
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

extension ChatThreadViewModel.SelectedProjectInfo {
  /// Whether the project is a Swift package
  var isSwiftPackage: Bool {
    dirPath != path
  }
}
