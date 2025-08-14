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
    userDefaults: UserDefaultsI)
  {
    self.settingsService = settingsService
    self.userDefaults = userDefaults
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

  private var cancellables = Set<AnyCancellable>()
  private var port: Int?
  private let settingsService: SettingsService
  private let userDefaults: UserDefaultsI

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

      defaultLogger.log("HTTP server for Chat completino started on port \(port)")

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
        ModelResult(id: model.id, created: 0, object: "model", ownedBy: "cmd")
      },
      object: "list")
  }

  private func chatCompletion(req _: Request) async throws -> BroadcastedStream<ChatStreamResult> {
    let (stream, continuation) = BroadcastedStream<ChatStreamResult>.makeStream()

    let completionId = UUID().uuidString

    Task.detached {
      continuation.yield(ChatStreamResult(
        id: completionId,
        created: Date().timeIntervalSince1970,
        model: "",
        choices: [
          ChatStreamResult.Choice(
            index: 0,
            delta: .init(content: "Hi", audio: nil, role: nil, toolCalls: nil, _reasoning: nil, _reasoningContent: nil),
            logprobs: nil),
        ]))
      try await Task.sleep(nanoseconds: 1_000_000_000)
      continuation.yield(ChatStreamResult(
        id: completionId,
        created: Date().timeIntervalSince1970,
        model: "",
        choices: [
          ChatStreamResult.Choice(
            index: 0,
            delta: .init(content: "Hi", audio: nil, role: nil, toolCalls: nil, _reasoning: nil, _reasoningContent: nil),
            logprobs: nil),
        ]))
      continuation.finish()
    }
    return stream
  }

  // TODO: make this opt-in
  private func updateXcodeSettings(port: Int) throws {
    guard let xcodeSettings = UserDefaults(suiteName: "com.apple.dt.Xcode") else {
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
        try xcodeSettings.set(JSONEncoder().encode(settings), forKey: xcodeSettingsKey)
      } else if cmdSettings?.connectionDetails.asObject?["localhost"]?.asObject?["port"]?.asNumber != Double(port) {
        settings = settings.filter { $0.identifierUUID != cmdSettings?.identifierUUID }
        settings.append(connectionDetails)
        try xcodeSettings.set(JSONEncoder().encode(settings), forKey: xcodeSettingsKey)
      }
    } else {
      // Add a new entry in Xcode settings to support cmd as an AI backend
      try xcodeSettings.set(JSONEncoder().encode([connectionDetails]), forKey: xcodeSettingsKey)
    }
  }

}

// MARK: - BroadcastedStream + AsyncResponseEncodable

extension BroadcastedStream: AsyncResponseEncodable where Element: Encodable {
  public func encodeResponse(for _: Request) async throws -> Response {
    let response = Response(status: .ok)
    let body = Response.Body(stream: { writer in
      Task {
        do {
          for try await element in self {
            let data = try JSONEncoder().encode(element)
            _ = writer.write(.buffer(.init(data: data)))
          }
        } catch {
          defaultLogger.error("An error occured while responding to the chat completion", error)
          let data = Data(chunkWithError: error.localizedDescription)
          _ = writer.write(.buffer(ByteBuffer(data: data)))
        }
        _ = writer.write(.buffer(ByteBuffer(string: "data: [DONE]")))
        _ = writer.write(.end)
      }
    })

    response.body = body
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
  init(id: String, created: TimeInterval, model: String, choices: [ChatStreamResult.Choice]) {
    self.id = id
    object = "chat.completion.chunk"
    self.created = created
    self.model = model
    self.choices = choices
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
