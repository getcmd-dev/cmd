// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import Foundation
import FoundationInterfaces
import JRPCServiceInterface
import JSONFoundation
import LoggingServiceInterface
import SettingsServiceInterface
import ShellServiceInterface
import ThreadSafe

// MARK: - GithubCopilotServer

/// A client for the GitHub Copilot language server.
/// For each workspace, a separate instance of this server should be created as each instance tracks the state of recently code changes.
@ThreadSafe
public final class GithubCopilotServer: Sendable {

  init(executablePath: URL, workspaceRoot: URL, shellService: ShellService, fileManager: FileManagerI, jrpcService: JRPCService) {
    self.workspaceRoot = workspaceRoot
    self.shellService = shellService
    self.fileManager = fileManager
    self.jrpcService = jrpcService
    self.executablePath = executablePath

    let (initializedTransport, setInitializedTransport) = Future<StdioConnection, Error>.make()
    self.initializedTransport = initializedTransport
    self.setInitializedTransport = setInitializedTransport

    Task {
      do {
        let transport = try await self.start()
        setInitializedTransport(.success(transport))
      } catch {
        setInitializedTransport(.failure(error))
      }
    }
  }

  deinit {
    // Cancel all pending requests
    for (_, continuation) in pendingRequests {
      continuation.resume(throwing: CopilotError.processNotRunning)
    }
  }

  let notifications = PassthroughSubject<JRPCNotification, Never>()
  let executablePath: URL
  let initializedTransport: Future<StdioConnection, Error>
  let setInitializedTransport: @Sendable (Result<StdioConnection, Error>) -> Void

  func sendNotification(_ method: String, params: JSON?, initializingTransport: StdioConnection? = nil) async throws {
    let transport = try await {
      if let initializingTransport { return initializingTransport }
      return try await initializedTransport.value
    }()

    let notification = JRPCNotification(method: method, params: params)
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(notification)

    // LSP protocol requires Content-Length header
    let header = "Content-Length: \(jsonData.count)\r\n\r\n"
    var messageData = Data(header.utf8)
    messageData.append(jsonData)

    try await transport.send(messageData)
  }

  func sendRequest<Response: Decodable>(
    _ method: String,
    params: JSON?,
    initializingTransport: StdioConnection? = nil)
    async throws -> Response
  {
    let result = try await sendRawRequest(method, params: params, initializingTransport: initializingTransport)
    let resultData = try JSONEncoder().encode(result)
    return try JSONDecoder().decode(Response.self, from: resultData)
  }

  func sendRawRequest(_ method: String, params: JSON?, initializingTransport: StdioConnection? = nil) async throws -> JSON.Value {
    let transport = try await {
      if let initializingTransport { return initializingTransport }
      return try await initializedTransport.value
    }()

    let id = nextId
    nextId += 1

    let request = JRPCRequest(id: id, method: method, params: params?.asValue)

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(request)

    let jsonString = String(data: jsonData, encoding: .utf8)!
    defaultLogger.log("Sending: \(jsonString)\n")

    // LSP protocol requires Content-Length header
    // Note: StdioTransport will add \n after this, which is fine for LSP
    let header = "Content-Length: \(jsonData.count)\r\n\r\n"
    var messageData = Data(header.utf8)
    messageData.append(jsonData)

    try await transport.send(messageData)

    return try await withCheckedThrowingContinuation { continuation in
      pendingRequests[id] = continuation
    }
  }

  // MARK: - Authentication Methods

  // MARK: - Document Sync Methods

  func didOpenTextDocument(uri: String, languageId: String, version: Int, text: String) async throws {
    defaultLogger.trace("Opening document: \(uri)")
    let params = DidOpenTextDocumentParams(
      textDocument: TextDocumentItem(
        uri: uri,
        languageId: languageId,
        version: version,
        text: text))

    try await sendNotification("textDocument/didOpen", params: .init(encoding: params))
  }

  func didChangeTextDocument(uri: String, version: Int, text: String) async throws {
    defaultLogger.trace("Document changed: \(uri)")
    let params = DidChangeTextDocumentParams(
      textDocument: TextDocumentIdentifier(uri: uri, version: version),
      contentChanges: [TextDocumentContentChangeEvent(text: text)])

    try await sendNotification("textDocument/didChange", params: .init(encoding: params))
  }

  func didSaveTextDocument(uri: String, version: Int, text: String?) async throws {
    defaultLogger.trace("Document saved: \(uri)")
    let params = DidSaveTextDocumentParams(
      textDocument: TextDocumentIdentifier(uri: uri, version: version),
      text: text)

    try await sendNotification("textDocument/didSave", params: .init(encoding: params))
  }

  func didCloseTextDocument(uri: String, version: Int) async throws {
    defaultLogger.trace("Document closed: \(uri)")
    let params = DidCloseTextDocumentParams(
      textDocument: TextDocumentIdentifier(uri: uri, version: version))

    try await sendNotification("textDocument/didClose", params: .init(encoding: params))
  }

  // MARK: - Completion Methods

  func getCompletions(
    uri: String,
    version: Int,
    position: Position,
    tabSize: Int,
    insertSpaces: Bool)
    async throws -> InlineCompletionList
  {
    defaultLogger.log("Requesting completions at \(uri) line:\(position.line) char:\(position.character) (version: \(version))")

    let params = InlineCompletionParams(
      textDocument: TextDocumentIdentifier(uri: uri, version: version),
      position: position,
      formattingOptions: FormattingOptions(tabSize: tabSize, insertSpaces: insertSpaces),
      context: InlineCompletionContext(triggerKind: 1), // Invoked
    )

    let result: InlineCompletionList = try await sendRequest("textDocument/inlineCompletion", params: .init(encoding: params))

    defaultLogger.log("Received \(result.items.count) completions")
    for (index, item) in result.items.enumerated() {
      defaultLogger.log(" [\(index)] \(item.insertText.prefix(50))...")
    }

    return result
  }

  private var nextId = 1
  private var pendingRequests = [Int: CheckedContinuation<JSON.Value, Error>]()

  private let shellService: ShellService
  private let workspaceRoot: URL
  private let fileManager: FileManagerI
  private let jrpcService: JRPCService

  private func start() async throws -> StdioConnection {
    defaultLogger.trace("Starting Copilot language server...")
    defaultLogger.trace("Executable path: \(executablePath.path)")

    // Create transport with command
    let command = "\"\(executablePath.path)\" --stdio"
    defaultLogger.trace("Command: \(command)")

    let env = await shellService.env
    let transport = jrpcService.createConnection(command: command, env: env, pwd: nil, delimitation: .contentLength)
    defaultLogger.trace("Transport created, about to connect...")

    // Set up disconnection handler before connecting
    await transport.onDisconnection { error in
      if let error {
        defaultLogger.error("Language server disconnected with error", error)
      } else {
        defaultLogger.trace("Language server disconnected")
      }
    }

    defaultLogger.trace("About to connect to stdio transport")
    try await transport.connect()
    defaultLogger.trace("Connected to stdio transport")

    // Start reading responses
    startReading(from: transport)

    // Initialize the language server
    try await initialize(initializingTransport: transport)

    defaultLogger.trace("Copilot language server started")

    return transport
  }

  // MARK: - Message Handling

  private func startReading(from transport: StdioConnection) {
    Task {
      do {
        let stream = await transport.receive()
        var messageCount = 0
        for try await message in stream {
          messageCount += 1
          try await handle(message: message)
        }
      } catch {
        defaultLogger.error("Error reading from transport", error)
      }
    }
  }

  private func handle(message: Data) async throws {
    let message = try JSONDecoder().decode(JRPCMessage.self, from: message)

    switch message {
    case .notification(let notification):
      handle(notification: notification)

    case .response(let response):
      let id = response.id
      if let continuation = pendingRequests.removeValue(forKey: id) {
        if let error = response.error {
          continuation.resume(throwing: JRPCResponseError(error: error))
        } else if let result = response.result {
          continuation.resume(returning: result)
        } else {
          continuation.resume(throwing: AppError("Invalid JRPC response: no result or error"))
        }
      } else {
        defaultLogger.error("No pending JRPC request found for id: \(id)")
      }

    case .request(let request):
      await handle(request: request)
    }
  }

  private func handle(request: JRPCRequest) async {
    let method = request.method
    let params = request.params
    let id = request.id
    defaultLogger.log("Handling server request: \(method)")

    let response: JRPCResponse

    switch method {
    case "workspace/configuration":
      if
        let request = try? params?.decode(as: WorkspaceConfigurationRequestParameters.self),
        let data = try? WorkspaceConfigurationBuilder.buildResponse(for: request)
      {
        defaultLogger.log(" → Responding with \(request.items.count) configurations")
        response = JRPCResponse(id: id, result: data, error: nil)
      } else {
        defaultLogger.log(" → No items requested, responding with empty array")
        response = JRPCResponse(id: id, result: .array([]), error: nil)
      }

    case "copilot/watchedFiles":
      // Server is asking for watched files
      defaultLogger.log(" → Responding with null (no files to watch)")
      response = JRPCResponse(id: id, result: .null, error: nil)

    default:
      defaultLogger.log(" → Unknown request method \(method), responding with null")
      response = JRPCResponse(id: id, result: .null, error: nil)
    }

    do {
      let jsonData = try JSONEncoder().encode(response)

      let header = "Content-Length: \(jsonData.count)\r\n\r\n"
      var messageData = Data(header.utf8)
      messageData.append(jsonData)

      let transport = try await initializedTransport.value
      try await transport.send(messageData)
    } catch {
      defaultLogger.log("Failed to send response to server request: \(error)")
    }
  }

  // MARK: - LSP Initialize

  private func initialize(initializingTransport: StdioConnection) async throws {
    let params = InitializeParams(
      processId: Int(ProcessInfo.processInfo.processIdentifier),
      rootUri: workspaceRoot.path,
      initializationOptions: [
        "editorInfo": .object(["name": "Xcode", "version": "1.0"]),
        "editorPluginInfo": .object(["name": "copilot-plugin", "version": "1.0"]),
        "copilotCapabilities": .object([
          "watchedFiles": true,
          "didChangeFeatureFlags": true,
          "stateDatabase": true,
        ]),
      ],
      capabilities: ClientCapabilities(),
      workspaceFolders: [
        WorkspaceFolder(uri: workspaceRoot.absoluteString, name: workspaceRoot.lastPathComponent),
      ])

    let result: InitializeResult = try await sendRequest(
      "initialize",
      params: .init(encoding: params),
      initializingTransport: initializingTransport)
    _ = result

    // Send initialized notification with empty object
    try await sendNotification("initialized", params: .object([:]), initializingTransport: initializingTransport)

//    // Give the language server a moment to process the initialized notification
//    // The agent service needs to be fully initialized before accepting other requests
//    defaultLogger.log("Waiting for agent service to initialize...")
//    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
//
//    defaultLogger.log("Language server initialized")
  }

  // MARK: - Notification Handling

  private func handle(notification: JRPCNotification) {
    notifications.send(notification)
  }
}

// MARK: - CopilotError

enum CopilotError: Error {
  case notConnected
  case notInitialized
  case processNotRunning
}
