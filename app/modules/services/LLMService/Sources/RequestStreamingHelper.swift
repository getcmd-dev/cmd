// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatFoundation
import ConcurrencyFoundation
import Foundation
import LLMServiceInterface
import LoggingServiceInterface
import ServerServiceInterface
import ThreadSafe
import ToolFoundation

// MARK: - RequestStreamingHelper

/// Receives streamed data from the serevr, and processes it to update the `result` stream with the new content.
/// Parse tool request, handle text and tool streaming.,
@ThreadSafe
final class RequestStreamingHelper: Sendable {
  #if DEBUG
  /// - Parameters:
  ///   - stream: The stream of data received from the server.
  ///   - result: The processed result that should be updated as we receive new data.
  ///   - tools: The list of tools available to the assistant.
  ///   - context: The context in which the request is executed.
  ///   - isTaskCancelled: A closure that returns whether the task has been cancelled.
  ///   - repeatDebugHelper: A debug helper that will repeat the last streamed responses, regardless of the current input.
  init(
    stream: AsyncThrowingStream<Data, any Error>,
    result: MutableCurrentValueStream<AssistantMessage>,
    tools: [any ToolFoundation.Tool],
    context: (any ChatContext)?,
    isTaskCancelled: @escaping @Sendable () -> Bool,
    repeatDebugHelper: RepeatDebugHelper?)
  {
    self.stream = stream
    self.result = result
    self.tools = tools
    self.context = context
    self.isTaskCancelled = isTaskCancelled
    self.repeatDebugHelper = repeatDebugHelper
  }
  #else
  /// - Parameters:
  ///   - stream: The stream of data received from the server.
  ///   - result: The processed result that should be updated as we receive new data.
  ///   - tools: The list of tools available to the assistant.
  ///   - context: The context in which the request is executed.
  ///   - isTaskCancelled: A closure that returns whether the task has been cancelled.
  init(
    stream: AsyncThrowingStream<Data, any Error>,
    result: MutableCurrentValueStream<AssistantMessage>,
    tools: [any ToolFoundation.Tool],
    context: (any ChatContext)?,
    isTaskCancelled: @escaping @Sendable () -> Bool)
  {
    self.stream = stream
    self.result = result
    self.tools = tools
    self.context = context
    self.isTaskCancelled = isTaskCancelled
  }
  #endif

  let result: MutableCurrentValueStream<AssistantMessage>
  let stream: AsyncThrowingStream<Data, any Error>
  let tools: [any ToolFoundation.Tool]
  let context: (any ChatContext)?
  var err: Error? = nil
  var streamingToolUse: (any ToolUse)? = nil
  var streamingToolUseInput = ""

  /// Handle all the streamed data, updating the `result` stream with the new content.
  ///  The `result` stream will always be complete when this method returns, either with a final message or an error.
  func processStream() async throws {
    do {
      for try await chunk in stream {
        do {
          #if DEBUG
          repeatDebugHelper?.receive(chunk: chunk)
          #endif
          guard !isTaskCancelled() else {
            // This should not be necessary. Cancelling the task should make the post request fail with an error.
            // TODO: look at removing this, which can also lead to `.finish()` being called twice on the stream.
            finish()
            break
          }

          let event = try JSONDecoder().decode(Schema.StreamedResponseChunk.self, from: chunk)

          let previousChunkIdx = _internalState.set(\.lastChunkIdx, to: event.idx)
          if event.idx <= previousChunkIdx {
            defaultLogger.error("Received chunks out of order. This will lead to corrupted data being used in the app.")
          }

          switch event {
          case .ping:
            break

          case .textDelta(let textDelta):
            handle(textDelta: textDelta)

          case .toolUseDelta(let toolUseDelta):
            await handle(toolUseDelta: toolUseDelta)

          case .toolUseRequest(let toolUseRequest):
            await handle(toolUseRequest: toolUseRequest)

          case .responseError(let error):
            // We received an error from the server.
            err = err ?? AppError(message: error.message)

          case .reasoningDelta(let reasoningDelta):
            handle(reasoningDelta: reasoningDelta)

          case .reasoningSignature(let reasoningSignature):
            handle(reasoningSignature: reasoningSignature)
          }
        } catch {
          defaultLogger.error("Failed to process chunk \(String(data: chunk, encoding: .utf8) ?? "<corrupted>"): \(error)")
          throw error
        }
      }
      try Task.checkCancellation()
      if let err {
        throw err
      }
      finish()
    } catch {
      defaultLogger.error("Finished streaming response with error \(error)")
      finish()
      throw error
    }
  }

  private let isTaskCancelled: @Sendable () -> Bool
  private var lastChunkIdx = -1

  #if DEBUG
  private let repeatDebugHelper: RepeatDebugHelper?
  #endif

  private static func missingToolError(toolName name: String) -> Error {
    NSError(
      domain: "ToolUseError",
      code: 0,
      userInfo: [NSLocalizedDescriptionKey: "Missing tool \(name)"])
  }

  private static func failedToParseToolInputError(toolName name: String, error: Error) -> Error {
    NSError(
      domain: "ToolUseError",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Could not parse the input for tool \(name): \(error.localizedDescription)"])
  }

  /// Wrap up the stream. When the stream is process without failure this is already called.
  private func finish() {
    endPreviousContent()
    result.finish()

    #if DEBUG
    repeatDebugHelper?.streamCompleted()
    #endif
  }

  private func handle(textDelta: Schema.TextDelta) {
    if let textContent = result.content.last?.asText {
      // We received a new text chunk, we'll append it to the last text content.
      let lastMessage = textContent.value
      let newMessage = TextContentMessage(
        content: lastMessage.content + textDelta.text,
        deltas: lastMessage.deltas + [textDelta.text])
      textContent.update(with: newMessage)
    } else {
      // Create a new text content.
      endPreviousContent()
      let newContent = TextContentMessage(content: textDelta.text, deltas: [textDelta.text])
      var content = result.content
      content.append(.text(MutableCurrentValueStream(newContent)))
      result.update(with: AssistantMessage(content: content))
    }
  }

  private func handle(toolUseDelta: Schema.ToolUseDelta) async {
    endPreviousContent()
    guard let context else {
      defaultLogger.error("No context available to handle tool use.")
      return
    }

    let toolName = toolUseDelta.toolName
    let toolUseId = toolUseDelta.toolUseId

    guard let tool = tools.first(where: { $0.name == toolName }) else {
      // The tool is not known. This is an error.
      // We don't handle the error on every partial update. We expect to later receive the same erronous tool name as a complete tool use request where we'll handle it.
      return
    }
    guard tool.canInputBeStreamed else {
      // The tool doesn't support streaming input. It'll be called at a latter point with the full input.
      return
    }

    streamingToolUseInput += toolUseDelta.inputDelta

    do {
      let (data, _) = try streamingToolUseInput.extractPartialJSON()
      var content = result.content
      if let streamingToolUse {
        assert(
          streamingToolUse.toolUseId == toolUseId,
          "Received a tool input while a different tool use is still streaming.")
        // If we already have an existing instance for this tool use, update it with the newly received data.
        try streamingToolUse.receive(inputUpdate: data, isLast: false)
      } else {
        // ready to start streaming a new tool use
        let toolUse = try tool.use(
          toolUseId: toolUseId,
          input: data,
          isInputComplete: false,
          context: ToolExecutionContext(
            project: context.project,
            projectRoot: context.projectRoot))

        if !toolUse.isReadonly {
          await context.prepareForWriteToolUse()
        }
        streamingToolUse = toolUse
        content.append(toolUse: toolUse)
        result.update(with: AssistantMessage(content: content))
      }

    } catch {
      // If the above fails, this is because the input could not be parsed by the tool.
      // While we are receiving the input, it can happen that we don't have enough data to parse the input well
      // so we do nothing with the error here.
      // If the input is not complete when we start receiving the next content, or when the stream ends, we'll set the tool use as failed.
    }
  }

  private func startExecution(of toolUse: any ToolUse, context: any ChatContext) async {
    do {
      try await context.requestToolApproval(toolUse)
      toolUse.startExecuting()
    } catch is CancellationError {
      defaultLogger.error("Tool use is cancelled")
      toolUse.cancel()
    } catch let error as LLMServiceError {
      defaultLogger.error("Tool approval is denied: \(error)")
      switch error {
      case .toolUsageDenied(let reason):
        toolUse.reject(reason: reason)
      }
    } catch {
      defaultLogger.error("Tool approval is denied: \(error)")
      // Reject the tool use instead of replacing it
      toolUse.reject(reason: error.localizedDescription)
    }
  }

  private func handle(toolUseRequest: Schema.ToolUseRequest) async {
    endPreviousContent()
    guard let context else {
      defaultLogger.error("No context available to handle tool use.")
      return
    }

    if let toolUse = streamingToolUse {
      if toolUse.toolUseId != toolUseRequest.toolUseId {
        assertionFailure("Received a tool use request for a different tool use ID while already streaming a tool use.")
      }
      do {
        try toolUse.receive(inputUpdate: toolUseRequest.input.asJSONData(), isLast: true)
      } catch {
        // If the above fails, this is because the input could not be parsed by the tool.
        var content = result.content
        assert(
          content.last?.asToolUseRequest?.toolUse.toolUseId == toolUse.toolUseId,
          "The last content should be the tool use request we are ending.")
        content.removeLast()
        content.append(toolUse: FailedToolUse(
          toolUseId: toolUse.toolUseId,
          toolName: toolUse.toolName,
          errorDescription: Self.failedToParseToolInputError(toolName: toolUse.toolName, error: error).localizedDescription))
        result.update(with: AssistantMessage(content: content))
      }
      endStreamedToolUse()
      await startExecution(of: toolUse, context: context)
      return
    }

    if result.content.last?.asToolUseRequest?.toolUse.toolUseId == toolUseRequest.toolUseId {
      // We have already processed the tool use.
      return
    }

    // Deal with non streaming tool use.
    var content = result.content
    let request = ToolUseRequestMessage(
      toolName: toolUseRequest.toolName,
      input: toolUseRequest.input,
      toolUseId: toolUseRequest.toolUseId,
      idx: toolUseRequest.idx)

    let toolExecutionContext = ToolExecutionContext(project: context.project, projectRoot: context.projectRoot)
    if let tool = tools.first(where: { $0.name == request.toolName }) {
      do {
        let data = try JSONEncoder().encode(request.input)
        let toolUse = try tool.use(
          toolUseId: request.toolUseId,
          input: data,
          isInputComplete: true,
          context: toolExecutionContext)

        if !toolUse.isReadonly {
          await context.prepareForWriteToolUse()
        }
        content.append(toolUse: toolUse)

        await startExecution(of: toolUse, context: context)

      } catch {
        // If the above fails, this is because the input could not be parsed by the tool.
        content.append(toolUse: FailedToolUse(
          toolUseId: request.toolUseId,
          toolName: request.toolName,
          errorDescription: Self.failedToParseToolInputError(toolName: request.toolName, error: error).localizedDescription))
      }
    } else {
      // Tool not found
      content.append(toolUse: FailedToolUse(
        toolUseId: request.toolUseId,
        toolName: request.toolName,
        errorDescription: Self.missingToolError(toolName: request.toolName).localizedDescription))
    }
    result.update(with: AssistantMessage(content: content))
  }

  private func endStreamedToolUse() {
    streamingToolUse = nil
    streamingToolUseInput = ""
  }

  private func endPreviousContent() {
    result.content.last?.asText?.finish()
    result.content.last?.asReasoning?.finish()
  }

  private func handle(reasoningDelta: Schema.ReasoningDelta) {
    if let reasoningContent = result.content.last?.asReasoning {
      // We received a new text chunk, we'll append it to the last reasoning content.
      let lastMessage = reasoningContent.value
      let newMessage = ReasoningContentMessage(
        content: lastMessage.content + reasoningDelta.delta,
        deltas: lastMessage.deltas + [reasoningDelta.delta],
        signature: lastMessage.signature)
      reasoningContent.update(with: newMessage)
    } else {
      // Create a new reasoning content.
      endPreviousContent()
      let newContent = ReasoningContentMessage(content: reasoningDelta.delta, deltas: [reasoningDelta.delta])
      var content = result.content
      content.append(.reasoning(MutableCurrentValueStream(newContent)))
      result.update(with: AssistantMessage(content: content))
    }
  }

  private func handle(reasoningSignature: Schema.ReasoningSignature) {
    if let reasoningContent = result.content.last?.asReasoning {
      let lastMessage = reasoningContent.value
      let newMessage = ReasoningContentMessage(
        content: lastMessage.content,
        deltas: lastMessage.deltas,
        signature: reasoningSignature.signature)
      reasoningContent.update(with: newMessage)
    } else {
      // Create a new reasoning content.
      endPreviousContent()
      let newContent = ReasoningContentMessage(content: "", deltas: [], signature: reasoningSignature.signature)
      var content = result.content
      content.append(.reasoning(MutableCurrentValueStream(newContent)))
      result.update(with: AssistantMessage(content: content))
    }
  }

}

extension Schema.StreamedResponseChunk {
  var idx: Int {
    switch self {
    case .ping(let ping):
      ping.idx
    case .textDelta(let textDelta):
      textDelta.idx
    case .toolUseDelta(let toolUseDelta):
      toolUseDelta.idx
    case .toolUseRequest(let toolUseRequest):
      toolUseRequest.idx
    case .responseError(let error):
      error.idx
    case .reasoningDelta(let reasoningDelta):
      reasoningDelta.idx
    case .reasoningSignature(let reasoningSignature):
      reasoningSignature.idx
    }
  }
}
