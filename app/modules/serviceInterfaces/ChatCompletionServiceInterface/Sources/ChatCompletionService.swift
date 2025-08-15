// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

// MARK: - ChatCompletionService

/// The `ChatCompletionService` supports a chat completion API compatible with OpenAI's API specs that allows for external applications
/// to use `cmd` as their AI backend. Most notably this can be used by the AI assistant in Xcode 26.
public protocol ChatCompletionService: Sendable {
  /// Start the HTTP server that handles the Chat completion API.
  func start()
  /// Register a handler that will handle chat completion requests by providing status updates in a way that
  /// the `ChatCompletionService` can use to stream response back to its client.
  func register(delegate: ChatCompletionServiceDelegate)
}

// MARK: - ChatCompletionServiceDelegate

public protocol ChatCompletionServiceDelegate: Sendable, AnyObject {

  /// Handle a new request for chat completion.
  ///
  /// Each new value in the stream is expected to contain all the chat events that happened since processing the last user messages.
  /// If the order is not consistent between streamed values, the receiver will take care of appending to its streamed content events not yet seen.
  /// ie the sender doesn't need to care too much about events ordering. However events cannot be updated, ie each event should only be sent
  /// once it has reached a final state. ex:
  ///
  ///   Chat thread state                |  Events sent to handler                             |  Serialized result
  ///   - tool use 1 pending             |  [                                                  |
  ///   - tool use 2 pending             |   ]                                                 |
  ///
  ///   - tool use 1 pending             | [                                                   |  run command B
  ///   - tool use 2 done                |  { id: 2, content: "run command B" }]               |
  ///
  ///   - tool use 1 done                | [{ id: 1, content: "run command A" }                |  run command B \n run command A
  ///   - tool use 2 done                |  { id: 2, content: "run command B" }]               |
  ///
  func handle(chatCompletion: ChatCompletionInput) async throws -> AsyncStream<[ChatEvent]>
}

// MARK: - ChatCompletionInput

public struct ChatCompletionInput: Sendable {
  /// The identifier of the thread that is resumed or created. If this doesn't match any known thread it is assumed that this is a new thread.
  public let threadId: String
  /// The messages sent by the user since the last assistant message. They should be added to the thread.
  public let newUserMessages: [String]

  public let modelName: String

  public init(threadId: String, newUserMessages: [String], modelName: String) {
    self.threadId = threadId
    self.newUserMessages = newUserMessages
    self.modelName = modelName
  }
}

// MARK: - ChatEvent

public struct ChatEvent: Sendable {
  /// An identifier for the event.
  public let id: String
  /// A string representation of the event.
  public let content: String

  public init(id: String, content: String) {
    self.id = id
    self.content = content
  }
}
