// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import Foundation
import FoundationInterfaces
import LoggingServiceInterface
import SettingsServiceInterface
import ShellServiceInterface
import ThreadSafe

// MARK: - GithubCopilotServer

@ThreadSafe
public final class GithubCopilotServer: Sendable {

  init(executablePath: URL, workspaceRoot: URL, shellService: ShellService, fileManager: FileManagerI) {
    self.workspaceRoot = workspaceRoot
    self.shellService = shellService
    self.fileManager = fileManager
    self.executablePath = executablePath

    let (didInitialize, setDidInitialize) = Future<Void, Error>.make()
    self.didInitialize = didInitialize
    self.setDidInitialize = setDidInitialize

    Task {
      do {
        _ = try await self.start()
        setDidInitialize(.success(()))
      } catch {
        setDidInitialize(.failure(error))
      }
    }
  }

  deinit {
    // Cancel all pending requests
    for (_, continuation) in pendingRequests {
      continuation.resume(throwing: CopilotError.processNotRunning)
    }
  }

  let executablePath: URL
  let didInitialize: Future<Void, Error>
  let setDidInitialize: @Sendable (Result<Void, Error>) -> Void

  func sendRequest(_ method: String, params: (some Encodable)?) async throws -> Data {
    guard let transport else {
      throw CopilotError.notConnected
    }

    let id = nextId
    nextId += 1

    let request =
      if let params {
        JSONRPCRequest(id: id, method: method, params: params)
      } else {
        JSONRPCRequest(id: id, method: method, params: nil as String?)
      }

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
    try await didInitialize.value

    defaultLogger.log("Opening document: \(uri)")
    let params = DidOpenTextDocumentParams(
      textDocument: TextDocumentItem(
        uri: uri,
        languageId: languageId,
        version: version,
        text: text))

    try await sendNotification("textDocument/didOpen", params: params)
  }

  func didChangeTextDocument(uri: String, version: Int, text: String) async throws {
    try await didInitialize.value

    defaultLogger.log("Document changed: \(uri)")
    let params = DidChangeTextDocumentParams(
      textDocument: TextDocumentIdentifier(uri: uri, version: version),
      contentChanges: [TextDocumentContentChangeEvent(text: text)])

    try await sendNotification("textDocument/didChange", params: params)
  }

  func didSaveTextDocument(uri: String, version: Int, text: String?) async throws {
    try await didInitialize.value

    defaultLogger.log("Document saved: \(uri)")
    let params = DidSaveTextDocumentParams(
      textDocument: TextDocumentIdentifier(uri: uri, version: version),
      text: text)

    try await sendNotification("textDocument/didSave", params: params)
  }

  func didCloseTextDocument(uri: String, version: Int) async throws {
    try await didInitialize.value

    defaultLogger.log("Document closed: \(uri)")
    let params = DidCloseTextDocumentParams(
      textDocument: TextDocumentIdentifier(uri: uri, version: version))

    try await sendNotification("textDocument/didClose", params: params)
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
    try await didInitialize.value

    defaultLogger.log("Requesting completions at \(uri) line:\(position.line) char:\(position.character) (version: \(version))")

    let params = InlineCompletionParams(
      textDocument: TextDocumentIdentifier(uri: uri, version: version),
      position: position,
      formattingOptions: FormattingOptions(tabSize: tabSize, insertSpaces: insertSpaces),
      context: InlineCompletionContext(triggerKind: 1), // Invoked
    )

    let resultData = try await sendRequest("textDocument/inlineCompletion", params: params)
    let decoder = JSONDecoder()
    let result = try decoder.decode(InlineCompletionList.self, from: resultData)

    defaultLogger.log("Received \(result.items.count) completions")
    for (index, item) in result.items.enumerated() {
      defaultLogger.log(" [\(index)] \(item.insertText.prefix(50))...")
    }

    return result
  }

  private var transport: StdioTransport?
  private var nextId = 1
  private var pendingRequests = [Int: CheckedContinuation<Data, Error>]()

  private let shellService: ShellService
  private let workspaceRoot: URL
  private let fileManager: FileManagerI

  private func start() async throws {
    defaultLogger.log("Starting Copilot language server...")
    defaultLogger.log("Executable path: \(executablePath.path)")

    // Create transport with command
    let command = "\"\(executablePath.path)\" --stdio"
    defaultLogger.log("Command: \(command)")

    let transport = StdioTransport(command: command, shellService: shellService)
    defaultLogger.log("Transport created, about to connect...")

    // Store transport before connecting to prevent deallocation
    self.transport = transport

    // Set up disconnection handler before connecting
    await transport.onDisconnection { error in
      if let error {
        defaultLogger.log("Language server disconnected with error: \(error)")
      } else {
        defaultLogger.log("Language server disconnected")
      }
    }

    defaultLogger.log("About to call connect()...")
    try await transport.connect()
    defaultLogger.log("Connect completed successfully")

    // Start reading responses
    startReading()

    // Initialize the language server
    try await initialize()

    defaultLogger.log("Copilot language server started")
  }

  // MARK: - Message Handling

  private func startReading() {
    guard let transport else {
      defaultLogger.log("startReading: transport is nil")
      return
    }

    defaultLogger.log("Starting to read from transport...")

    Task {
      do {
        defaultLogger.log("Entering receive loop...")
        let stream = await transport.receive()
        defaultLogger.log("Got stream, starting iteration...")

        var messageCount = 0
        for try await data in stream {
          messageCount += 1
          defaultLogger.log("Received data chunk #\(messageCount) of size: \(data.count)")
          try await handleMessage(data)
        }
        defaultLogger.log("Stream ended after \(messageCount) messages")
      } catch {
        defaultLogger.log("Error reading from transport: \(error)")
      }
    }

    // Add a heartbeat to confirm reading loop is alive
    Task {
      try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
      defaultLogger.log("Reading loop heartbeat - still waiting for messages...")
    }
  }

  private func handleMessage(_ data: Data) async throws {
    let jsonString = String(data: data, encoding: .utf8) ?? "<invalid utf8>"
    defaultLogger.log("Received: \(jsonString)")

    // Parse as generic JSON first to determine message type
    guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      defaultLogger.log("Failed to parse message as JSON object")
      return
    }

    let hasMethod = jsonObject["method"] != nil
    let hasId = jsonObject["id"] != nil
    let hasResult = jsonObject["result"] != nil
    let hasError = jsonObject["error"] != nil

    if hasMethod, hasId {
      // This is a REQUEST from the server
      let method = jsonObject["method"] as! String
      let id = jsonObject["id"]!
      defaultLogger.log("Request FROM server: \(method) (id=\(id))")
      await handleServerRequest(method: method, id: id, params: jsonObject["params"])
    } else if hasId, hasResult || hasError {
      // This is a RESPONSE to our request
      let decoder = JSONDecoder()
      let response = try decoder.decode(JSONRPCResponse.self, from: data)

      if let id = response.id {
        defaultLogger.log("Response has id: \(id)")
        if let continuation = pendingRequests.removeValue(forKey: id) {
          defaultLogger.log("Found pending request for id: \(id)")
          if let error = response.error {
            defaultLogger.log("Response has error: \(error)")
            continuation.resume(throwing: JSONRPCResponseError(error: error))
          } else if let result = response.result {
            defaultLogger.log("Response has result, encoding...")
            let resultData = try JSONEncoder().encode(result)
            defaultLogger.log("Resuming continuation with \(resultData.count) bytes")
            continuation.resume(returning: resultData)
          } else {
            defaultLogger.log("Response has no result or error, returning empty")
            continuation.resume(returning: Data())
          }
        } else {
          defaultLogger.log("No pending request found for id: \(id)")
        }
      }
    } else if hasMethod {
      // This is a NOTIFICATION from the server
      let method = jsonObject["method"] as! String
      defaultLogger.log("Notification: \(method)")
      let params = jsonObject["params"].map { AnyCodable($0) }
      handleNotification(method: method, params: params)
    }
  }

  private func handleServerRequest(method: String, id: Any, params: Any?) async {
    defaultLogger.log("Handling server request: \(method)")

    var result: Any? = nil

    switch method {
    case "workspace/configuration":
      // Server is asking for configuration
      if
        let params = params as? [String: Any],
        let items = params["items"] as? [[String: Any]]
      {
        defaultLogger.log(" → Responding with \(items.count) configurations")
        result = try? WorkspaceConfigurationBuilder.buildResponse(for: items)
        if result == nil {
          // Fallback to empty configs if building fails
          defaultLogger.log(" → Failed to build configurations, using empty")
          result = items.map { _ in [:] as [String: Any] }
        }
      } else {
        defaultLogger.log(" → No items requested, responding with empty array")
        result = []
      }

    case "copilot/watchedFiles":
      // Server is asking for watched files
      defaultLogger.log(" → Responding with null (no files to watch)")
      result = NSNull()

    default:
      defaultLogger.log(" → Unknown request method, responding with null")
      result = NSNull()
    }

    // Send response
    let response: [String: Any] = [
      "jsonrpc": "2.0",
      "id": id,
      "result": result ?? NSNull(),
    ]

    do {
      let jsonData = try JSONSerialization.data(withJSONObject: response)
      let jsonString = String(data: jsonData, encoding: .utf8)!
      defaultLogger.log("Sending response to server request (id=\(id)): \(jsonString)")

      let header = "Content-Length: \(jsonData.count)\r\n\r\n"
      var messageData = Data(header.utf8)
      messageData.append(jsonData)

      try await transport?.send(messageData)
    } catch {
      defaultLogger.log("Failed to send response to server request: \(error)")
    }
  }

  private func sendNotification(_ method: String, params: (some Encodable)?) async throws {
    guard let transport else {
      throw CopilotError.notConnected
    }

    let notification =
      if let params {
        JSONRPCNotification(method: method, params: params)
      } else {
        JSONRPCNotification(method: method, params: nil as String?)
      }

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(notification)

    let jsonString = String(data: jsonData, encoding: .utf8)!
    defaultLogger.log("Sending: \(jsonString)\n")

    // LSP protocol requires Content-Length header
    // Note: StdioTransport will add \n after this, which is fine for LSP
    let header = "Content-Length: \(jsonData.count)\r\n\r\n"
    var messageData = Data(header.utf8)
    messageData.append(jsonData)

    try await transport.send(messageData)
  }

  // MARK: - LSP Initialize

  private func initialize() async throws {
    let params = InitializeParams(
      processId: Int(ProcessInfo.processInfo.processIdentifier),
      rootUri: workspaceRoot.path,
      initializationOptions: [
        "editorInfo": AnyCodable(["name": "CopilotPlugin", "version": "1.0"]),
        "editorPluginInfo": AnyCodable(["name": "copilot-plugin", "version": "1.0"]),
        "copilotCapabilities": AnyCodable([
          "watchedFiles": true,
          "didChangeFeatureFlags": true,
        ]),
      ],
      capabilities: ClientCapabilities(),
      workspaceFolders: [
        WorkspaceFolder(uri: workspaceRoot.absoluteString, name: workspaceRoot.lastPathComponent),
      ])

    let resultData = try await sendRequest("initialize", params: params)
    let decoder = JSONDecoder()
    let _ = try decoder.decode(InitializeResult.self, from: resultData)

    // Send initialized notification with empty object
    let emptyParams = [String: String]()
    try await sendNotification("initialized", params: emptyParams)

    // Give the language server a moment to process the initialized notification
    // The agent service needs to be fully initialized before accepting other requests
    defaultLogger.log("Waiting for agent service to initialize...")
    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

    defaultLogger.log("Language server initialized")
  }

  // MARK: - Notification Handling

  private func handleNotification(method: String, params _: AnyCodable?) {
    defaultLogger.log("Notification: \(method)")

    switch method {
    case "$/progress":
      defaultLogger.log(" Progress update")
    case "copilot/didChangeFeatureFlags":
      defaultLogger.log(" Feature flags changed")
    case "copilot/didChangeStatus":
      defaultLogger.log(" Status changed")
    default:
      defaultLogger.log(" Unhandled notification")
    }
  }
}

// MARK: - CopilotError

enum CopilotError: Error {
  case notConnected
  case notInitialized
  case processNotRunning
}
