// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatCompletionServiceInterface
@preconcurrency import Combine
import ConcurrencyFoundation
import DependencyFoundation
import Foundation
import FoundationInterfaces
import JSONFoundation
import LoggingServiceInterface
import SettingsServiceInterface
import ThreadSafe
import Vapor

// MARK: - DefaultChatCompletionService

@ThreadSafe
final class DefaultChatCompletionService: ChatCompletionService {

  // MARK: - Initialization

  init(
    settingsService: SettingsService,
    userDefaults: UserDefaultsI,
    xcodeUserDefaults: UserDefaultsI? = UserDefaults(suiteName: "com.apple.dt.Xcode"))
  {
    self.settingsService = settingsService
    self.userDefaults = userDefaults
    self.xcodeUserDefaults = xcodeUserDefaults
  }

  func start() {
    Task {
      try await startServer()
    }

    /// When the setting to automatically sync Xcode settings is changed, do the sync if needed.
    settingsService.liveValue(for: \.automaticallyUpdateXcodeSettings).sink { @Sendable [weak self] value in
      if value, let port = self?.port {
        try? self?.updateXcodeSettings(port: port)
      }
    }.store(in: &cancellables)
  }

  func register(delegate: ChatCompletionServiceDelegate) {
    self.delegate = delegate
  }

  func configure(_ app: Application, port: Int) throws {
    // Configure to run on localhost only
    app.http.server.configuration.hostname = "127.0.0.1"
    app.http.server.configuration.port = port
    app.routes.defaultMaxBodySize = "10MB"

    app.get("v1", "models", use: getAvailableModels(req:))
    app.post("v1", "chat", "completions", use: chatCompletion(req:))
  }

  func updateXcodeSettings() {
    if let port {
      try? updateXcodeSettings(port: port)
    }
  }

  private weak var delegate: ChatCompletionServiceDelegate?

  private var cancellables = Set<AnyCancellable>()
  private var port: Int?
  private let settingsService: SettingsService
  private let userDefaults: UserDefaultsI
  private let xcodeUserDefaults: UserDefaultsI?

  /// Find an available port where to start the HTTP server.
  private func findAvailablePort() async throws -> Int {
    var port = 10101

    while true {
      if port >= 65535 {
        // 65535 = 2^16-1 is the max port number allowed for localhost
        throw AppError("Could not find available port to start local HTTP server for chat completion")
      }
      do {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/")!)
        request.httpMethod = "HEAD"
        _ = try await URLSession.shared.data(for: request)
        port += 1
      } catch {
        if let urlError = error as? URLError, urlError.code == .cannotConnectToHost {
          // The port is available
          break
        }
      }
    }
    return port
  }

  private func startServer() async throws {
    var env = try Environment.detect()
    try LoggingSystem.bootstrap(from: &env)

    do {
      let app = Application(env)
      defer {
        defaultLogger.error("The local HTTP server used to response to chat completion has shut down. This is unexpected.")
        app.shutdown()
      }
      let port = try await findAvailablePort()
      self.port = port
      try configure(app, port: port)
      try app.start()

      if settingsService.value(for: \.automaticallyUpdateXcodeSettings) == true {
        try? updateXcodeSettings(port: port)
      }

      defaultLogger.log("HTTP server for Chat completion started on port \(port)")

      // Keep the server running
      try await app.running?.onStop.get()
    } catch {
      defaultLogger.error(error)
    }
  }

  private func getAvailableModels(req _: Request) -> ModelsResult {
    ModelsResult(
      data:
      settingsService.liveValues().currentValue.availableModels.map { model in
        ModelResult(id: model.name, created: 0, object: "model", ownedBy: "cmd")
      },
      object: "list")
  }

  // TODO: find how to detect request cancellation by the client.
  private func chatCompletion(req: Request) async throws -> BroadcastedStream<ChatStreamResult> {
    let (stream, continuation) = BroadcastedStream<ChatStreamResult>.makeStream(replayStrategy: .replayAll)
    Task {
      let completionId = UUID().uuidString
      var model = "unknown"
      do {
        guard let data = req.body.data else {
          throw AppError("Missing request body")
        }

        let request = try JSONDecoder().decode(ChatQuery.self, from: data)
        model = request.model

        let threadId = {
          if let id = request.messages.threadId {
            return id
          } else {
            let id = UUID().uuidString

            continuation.yield(ChatStreamResult(
              completionId: completionId,
              model: model,
              content: "thread_id: \(id)\n\n"))
            return id
          }
        }()

        let newUserMessages = request.messages.newUserMessages

        if newUserMessages.isEmpty {
          throw AppError("No new message found")
        }
        guard let delegate else {
          throw AppError("No chat completion handler configured")
        }

        let chatEventsStream = try await delegate.handle(chatCompletion: ChatCompletionInput(
          threadId: threadId,
          newUserMessages: newUserMessages
            .flatMap(\.textContentParts)
            .map { text in
              // Remove the context provided by Xcode. It is not good and we are able to build our own context much better.
              let spl = text.split(separator: "The user has asked:")
              return (spl.last.map { String($0) } ?? text).trimmingCharacters(in: .whitespacesAndNewlines)
            },
          modelName: model))

        var sentEventIds: Set<String> = []

        for await chatEvents in chatEventsStream {
          let newEvents = chatEvents.filter { !sentEventIds.contains($0.id) }
          for newEvent in newEvents {
            sentEventIds.insert(newEvent.id)

            continuation.yield(ChatStreamResult(
              completionId: completionId,
              model: model,
              content: newEvent.content))
          }
        }
      } catch {
        continuation.yield(ChatStreamResult(
          completionId: completionId,
          model: model,
          content: "\(error.localizedDescription)\n"))
      }
      continuation.yield(ChatStreamResult(stoppingCompletionWithId: completionId, model: model))
      continuation.finish()
    }
    return stream
  }

  /// Directly modify Xcode settings to setup `cmd` as an AI backend or to sync its port.
  private func updateXcodeSettings(port: Int) throws {
    guard let xcodeSettings = xcodeUserDefaults else {
      defaultLogger.error("Could not find Xcode settings")
      return
    }

    let providerId = {
      let key = "cmd_xcode_provider_id"
      if let providerId = userDefaults.string(forKey: key) {
        return providerId
      } else {
        let providerId = UUID().uuidString
        userDefaults.set(providerId, forKey: key)
        return providerId
      }
    }()

    let connectionDetails = XcodeIDEChatUserChatModelProvider(
      isEnabled: true,
      identifierUUID: providerId,
      userDescription: "cmd",
      connectionDetails: ["localhost": ["port": .number(Double(port))]])
    let xcodeSettingsKey = "IDEChatUserChatModelProviders"
    if let data = xcodeSettings.data(forKey: xcodeSettingsKey) {
      // Ensures that the provider for cmd points to the correct port
      var settings = try JSONDecoder().decode([XcodeIDEChatUserChatModelProvider].self, from: data)
      let cmdSettings = settings.first(where: { $0.userDescription == "cmd" })
      if cmdSettings == nil {
        settings.append(connectionDetails)
        try xcodeSettings.set(JSONEncoder.sortingKeys.encode(settings), forKey: xcodeSettingsKey)
      } else if cmdSettings?.connectionDetails.asObject?["localhost"]?.asObject?["port"]?.asNumber != Double(port) {
        settings = settings.filter { $0.identifierUUID != cmdSettings?.identifierUUID }
        settings.append(connectionDetails)
        try xcodeSettings.set(JSONEncoder.sortingKeys.encode(settings), forKey: xcodeSettingsKey)
      }
    } else {
      // Add a new entry in Xcode settings to support cmd as an AI backend
      try xcodeSettings.set(JSONEncoder.sortingKeys.encode([connectionDetails]), forKey: xcodeSettingsKey)
    }
  }

}

// MARK: - BroadcastedStream + AsyncResponseEncodable

extension BroadcastedStream: AsyncResponseEncodable where Element: Encodable {
  public func encodeResponse(for _: Request) async throws -> Response {
    let response = Response(status: .ok)
    response.headers.contentType = HTTPMediaType(type: "text", subType: "event-stream")
    response.body = Response.Body(managedAsyncStream: { writer in
      do {
        for try await element in self {
          let data = try JSONEncoder.sortingKeys.encode(element)
          guard let string = String(data: data, encoding: .utf8) else {
            throw AppError("Could not convert Data to String in DefaultChatCompletionService")
          }
          _ = try await writer.write(.buffer(ByteBuffer(string: "data: \(string)\n\n")))
        }
      } catch {
        defaultLogger.error("An error occured while responding to the chat completion", error)
        let data = Data(chunkWithError: error.localizedDescription)
        _ = try await writer.write(.buffer(ByteBuffer(data: data)))
      }
      _ = try await writer.write(.buffer(ByteBuffer(string: "data: [DONE]")))
    })

    return response
  }
}

extension Data {
  /// A chunk that can be stream to the client to describe an error in the expected format.
  init(chunkWithError error: String) {
    self = "data: {\"error\": {\"message\": \"\(error)\" }}\n\n".utf8Data
  }
}

extension ChatStreamResult {
  init(
    completionId: String,
    created: TimeInterval = Date().timeIntervalSince1970,
    model: String,
    choices: [ChatStreamResult.Choice])
  {
    id = completionId
    object = "chat.completion.chunk"
    self.created = created
    self.model = model
    self.choices = choices
    citations = nil
    systemFingerprint = nil
  }

  init(completionId: String, created: TimeInterval = Date().timeIntervalSince1970, model: String, content: String) {
    id = completionId
    object = "chat.completion.chunk"
    self.created = created
    self.model = model
    choices = [ChatStreamResult.Choice(
      index: 0,
      delta: .init(content: content, audio: nil, role: .assistant, toolCalls: nil, _reasoning: nil, _reasoningContent: nil),
      finishReason: nil,
      logprobs: nil)]
    citations = nil
    systemFingerprint = nil
  }

  init(stoppingCompletionWithId completionId: String, created: TimeInterval = Date().timeIntervalSince1970, model: String) {
    id = completionId
    object = "chat.completion.chunk"
    self.created = created
    self.model = model
    choices = [ChatStreamResult.Choice(
      index: 0,
      delta: .init(content: nil, audio: nil, role: .assistant, toolCalls: nil, _reasoning: nil, _reasoningContent: nil),
      finishReason: .stop,
      logprobs: nil)]
    citations = nil
    systemFingerprint = nil
  }
}

extension ModelsResult: Content { }

private struct XcodeIDEChatUserChatModelProvider: Codable {
  let isEnabled: Bool
  let identifierUUID: String
  let userDescription: String
  let connectionDetails: JSON
}

// MARK: - Dependency Registration

extension BaseProviding where
  Self: SettingsServiceProviding,
  Self: UserDefaultsProviding
{
  public var chatCompletionService: ChatCompletionService {
    shared {
      DefaultChatCompletionService(
        settingsService: settingsService,
        userDefaults: sharedUserDefaults)
    }
  }
}
