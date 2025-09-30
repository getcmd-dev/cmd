// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Combine
import ConcurrencyFoundation
import DependencyFoundation
import Foundation
import FoundationInterfaces
import JSONFoundation
import LLMFoundation
import LLMServiceInterface
import LocalServerServiceInterface
import LoggingServiceInterface
import SettingsServiceInterface
import ShellServiceInterface
import ToolFoundation

// MARK: - DefaultLLMService

final class DefaultLLMService: LLMService {

  init(server: LocalServer, settingsService: SettingsService, userDefaults: UserDefaultsI, shellService: ShellService) {
    self.server = server
    self.settingsService = settingsService
    self.shellService = shellService

    #if DEBUG
    repeatDebugHelper = RepeatDebugHelper(userDefaults: userDefaults)
    #endif
  }

  func sendMessage(
    messageHistory: [Schema.Message],
    tools: [any ToolFoundation.Tool] = [],
    model: LLMModel,
    chatMode: ChatMode,
    context: any ChatContext,
    handleUpdateStream: (UpdateStream) -> Void)
    async throws -> SendMessageResponse
  {
    let response = MutableCurrentValueStream<[CurrentValueStream<AssistantMessage>]>([])
    handleUpdateStream(response)

    let usageInfo = Atomic<LLMUsageInfo?>(nil)

    do {
      var messageHistory = messageHistory
      // Iterate until we have received a response with no tool use request.
      while true {
        let newMessage = try await sendOneMessage(
          messageHistory: messageHistory,
          tools: tools,
          model: model,
          chatMode: chatMode,
          context: context,
          handleUpdateStream: { newMessage in
            // Add the new message to the response stream.
            var newMessages = response.value
            newMessages.append(newMessage)
            response.update(with: newMessages)
          },
          handleUsageInfo: { info in usageInfo.set(to: info) })

        // The new message is now entirely received. We can deal with tool calls.
        let toolUseRequests: [ToolUseMessage] = newMessage.content.compactMap { content in
          content.asToolUseRequest
        }
        if toolUseRequests.isEmpty {
          // No tool use, we are done.
          break
        }

        // Add to the message history the message just received.
        // This is important as the assistant needs to see the message with tool calls before the tool use results.
        try messageHistory.append(newMessage.message)

        // Execute each tool call.
        for toolUseRequest in toolUseRequests {
          try Task.checkCancellation()
          await messageHistory.append(Self.waitForResult(of: toolUseRequest))
        }

        if toolUseRequests.filter({ $0.toolUse as? any ExternalToolUse == nil }).isEmpty {
          // All tool uses are external, we don't need to send their result back to the assistant.
          break
        }
      }
      response.finish()
    } catch {
      response.finish()
      throw error
    }

    // At this point all the assistant messages have been received.
    // Return them to the caller.
    var messages = [AssistantMessage]()
    for message in response.value {
      let finalMessage = await message.lastValue
      messages.append(finalMessage)
    }
    return SendMessageResponse(newMessages: messages, usageInfo: usageInfo.value)
  }

  /// Call the `sendMessage` endpoint once.
  /// - Returns: The message received from the assistant.
  /// - Parameters:
  ///   - messageHistory: The historical context of all messages in the conversation. The last message is expected to be the last one sent by the user.
  ///   - tools: The tools available to the assistant.
  ///   - handleUpdateStream: A callback called synchronously with a stream that will broadcast updates about received messages. This can be usefull if you want to display the messages as they are streamed.
  ///   - handleUsageInfo: Closure called when usage information is available.
  func sendOneMessage(
    messageHistory: [Schema.Message],
    tools: [any ToolFoundation.Tool] = [],
    model: LLMModel,
    chatMode: ChatMode,
    context: any ChatContext,
    handleUpdateStream: (CurrentValueStream<AssistantMessage>) -> Void,
    handleUsageInfo: (Schema.ResponseUsage) -> Void)
    async throws -> AssistantMessage
  {
    let settings = settingsService.values()
    let customInstructions = customInstructions(for: chatMode, from: settings)
    let promptConfiguration = PromptConfiguration(
      projectRoot: context.projectRoot,
      mode: chatMode,
      customInstructions: customInstructions)

    return try await streamCompletionResponse(
      system: Prompt.defaultPrompt(configuration: promptConfiguration),
      messageHistory: messageHistory,
      tools: tools,
      model: model,
      enableReasoning: model.canReason && settings.reasoningModels[model]?.isEnabled == true,
      context: context,
      supportDebugStreamRepeatInDebug: true,
      handleUpdateStream: handleUpdateStream,
      handleUsageInfo: handleUsageInfo)
  }

  func nameConversation(firstMessage: String) async throws -> String {
    let settings = settingsService.values()
    guard let lowTierModel = settings.lowTierModel else {
      defaultLogger.error("Unable to name conversation: no low tier model available")
      return "New conversation"
    }
    if (try? settings.provider(for: lowTierModel))?.0.isExternalAgent == true {
      // extenal agent cannot be called to name conversations. The conversation name might however be read from their output.
      return "New conversation"
    }

    let assistantMessage = try await streamCompletionResponse(
      system: """
        Summarize this coding conversation in under 50 characters.\nCapture the main task, key files and problems addressed. Respond with ONLY the summary, nothing else

        good output example : `Fixing the login flow in the app`
        bad output example: `Here's a concise summary of the conversation: Fixing the login flow in the app`
        """,
      messageHistory: [.init(
        role: .user,
        content: [.textMessage(.init(text: "Please write a 5-10 word title the following conversation:\n\n\(firstMessage)"))])],
      tools: [],
      model: lowTierModel,
      enableReasoning: false,
      context: nil,
      handleUpdateStream: { _ in },
      handleUsageInfo: { _ in })

    return assistantMessage.content.first?.asText?.content ?? "New conversation"
  }

  func summarizeConversation(messageHistory: [Schema.Message], model: LLMModel) async throws -> String {
    var messages = messageHistory
    messages.append(.init(
      role: .user,
      content: [
        .textMessage(.init(
          text: "Please provide a comprehensive summary of this conversation, highlighting the main topics discussed, key decisions made, and any important outcomes or next steps.")),
      ]))

    let assistantMessage = try await streamCompletionResponse(
      system: Prompt.summarizationSystemPrompt,
      messageHistory: messages,
      tools: [],
      model: model,
      enableReasoning: false,
      context: nil,
      handleUpdateStream: { _ in },
      handleUsageInfo: { _ in })

    return assistantMessage.content.first?.asText?.content ?? ""
  }

  private let settingsService: SettingsService

  private let shellService: ShellService

  #if DEBUG
  private let repeatDebugHelper: RepeatDebugHelper
  #endif
  private let server: LocalServer

  /// Wait for the result of a tool use request.
  /// This returns a message representing the result of the tool use, and broadcast the execution status to the update stream.
  private static func waitForResult(
    of toolUseRequest: ToolUseMessage)
    async -> Schema.Message
  {
    let toolUse = toolUseRequest.toolUse

    do {
      let toolOutput = try await toolUse.output

      // TODO: try to avoid this.
      let data = try JSONEncoder().encode(toolOutput)
      let json = try JSONDecoder().decode(JSON.Value.self, from: data)

      let toolResult = Schema.ToolResultMessage(
        toolUseId: toolUse.toolUseId,
        toolName: toolUse.toolName,
        result: .toolResultSuccessMessage(.init(success: json)))
      return .init(role: .tool, content: [.toolResultMessage(toolResult)])
    } catch {
      let toolResult = Schema.ToolResultMessage(
        toolUseId: toolUse.toolUseId,
        toolName: toolUse.toolName,
        result: .toolResultFailureMessage(.init(failure: .string(error.localizedDescription))))
      return .init(role: .tool, content: [.toolResultMessage(toolResult)])
    }
  }

  /// Streams a completion response from the LLM service with real-time updates.
  /// - Parameters:
  ///   - system: The system prompt to guide the assistant's behavior
  ///   - messageHistory: Array of previous messages in the conversation
  ///   - tools: Available tools the assistant can use during the conversation
  ///   - model: The LLM model to use for generating the response
  ///   - enableReasoning: Whether to enable reasoning capabilities for the model
  ///   - context: Chat context containing conversation state and metadata
  ///   - supportDebugStreamRepeatInDebug: Whether to support debug stream repetition in debug mode
  ///   - handleUpdateStream: Closure called with streaming updates as the response is generated
  ///   - handleUsageInfo: Closure called when usage information is available.
  private func streamCompletionResponse(
    system: String,
    messageHistory: [Schema.Message],
    tools: [any ToolFoundation.Tool],
    model: LLMModel,
    enableReasoning: Bool,
    context: (any ChatContext)?,
    supportDebugStreamRepeatInDebug: Bool = false,
    handleUpdateStream: (CurrentValueStream<AssistantMessage>) -> Void,
    handleUsageInfo: (Schema.ResponseUsage) -> Void)
    async throws -> AssistantMessage
  {
    let settings = settingsService.values()
    let (provider, providerSettings) = try settings.provider(for: model)
    let params = try await Schema.SendMessageRequestParams(
      messages: messageHistory,
      system: system,
      projectRoot: context?.projectRoot?.path,
      tools: tools
        .filter { !$0.isExternalTool }
        .map { .init(name: $0.name, description: $0.description, inputSchema: $0.inputSchema) },
      model: provider.id(for: model),
      enableReasoning: enableReasoning,
      provider: .init(
        provider: provider,
        settings: providerSettings,
        shellService: shellService,
        projectRoot: context?.projectRoot?.path),
      threadId: context?.threadId)

    let encoder = JSONEncoder()
    // This is important, as in some cases if the LLM receives keys in a different order this will invalidate its cache and be expensive.
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(params)

    let result = MutableCurrentValueStream<AssistantMessage>(AssistantMessage(content: []), replayStrategy: .replayAll)
    handleUpdateStream(result)

    let isTaskCancelled = Atomic(false)

    return try await withTaskCancellationHandler(operation: {
      #if DEBUG
      let stream = {
        if supportDebugStreamRepeatInDebug, let stream = try? repeatDebugHelper.repeatStream() { return stream }
        // For external agents, allow for long timeouts
        return server.streamPostRequest(
          path: "sendMessage",
          data: data,
          idleTimeout: providerSettings.executable != nil ? 3600 : 120)
      }()

      let helper = RequestStreamingHelper(
        stream: stream,
        result: result,
        tools: tools,
        context: context,
        isTaskCancelled: { isTaskCancelled.value },
        localServer: server,
        repeatDebugHelper: supportDebugStreamRepeatInDebug ? repeatDebugHelper : nil)
      #else
      /// For external agents, allow for long timeouts
      let stream = server.streamPostRequest(
        path: "sendMessage",
        data: data,
        idleTimeout: providerSettings.executable != nil ? 3600 : 120)

      let helper = RequestStreamingHelper(
        stream: stream,
        result: result,
        tools: tools,
        context: context,
        isTaskCancelled: { isTaskCancelled.value },
        localServer: server)
      #endif

      let usage = try await helper.processStream()
      if let usage {
        handleUsageInfo(usage)
      }

      return await result.lastValue
    }, onCancel: {
      isTaskCancelled.mutate { $0 = true }
    })
  }

  /// Retrieves the appropriate custom instructions based on the chat mode.
  private func customInstructions(
    for chatMode: ChatMode,
    from settings: Settings)
    -> String?
  {
    switch chatMode {
    case .ask:
      settings.customInstructions.askMode
    case .agent:
      settings.customInstructions.agentMode
    }
  }
}

extension BaseProviding where
  Self: LocalServerProviding,
  Self: SettingsServiceProviding,
  Self: UserDefaultsProviding,
  Self: ShellServiceProviding
{
  public var llmService: LLMService {
    shared {
      DefaultLLMService(
        server: localServer,
        settingsService: settingsService,
        userDefaults: sharedUserDefaults,
        shellService: shellService)
    }
  }
}

extension [AssistantMessageContent] {
  mutating func append(toolUse: any ToolUse) {
    append(.tool(ToolUseMessage(toolUse: toolUse)))
  }
}

extension Schema.APIProvider {
  init(provider: LLMProvider, settings: LLMProviderSettings, shellService: ShellService, projectRoot: String?) async throws {
    let apiProviderName: Schema.APIProviderName = try {
      switch provider {
      case .anthropic:
        return .anthropic
      case .openAI:
        return .openai
      case .openRouter:
        return .openrouter
      case .claudeCode:
        return .claudeCode
      case .groq:
        return .groq
      case .gemini:
        return .gemini
      default:
        throw AppError(message: "Unsupported provider \(provider.name)")
      }
    }()
    let localExecutable: Schema.LocalExecutable? = await {
      guard let executable = settings.executable else { return nil }
      return await Schema.LocalExecutable(
        executable: executable,
        env: JSON(shellService.env),
        cwd: projectRoot)
    }()
    self = .init(
      name: apiProviderName,
      settings: .init(apiKey: settings.apiKey, baseUrl: settings.baseUrl, localExecutable: localExecutable))
  }
}

extension ChatContext {
  var project: URL? { toolExecutionContext.projectRoot }
  var projectRoot: URL? { toolExecutionContext.projectRoot }
  var threadId: String { toolExecutionContext.threadId }
}
