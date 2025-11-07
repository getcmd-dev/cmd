// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import CodeCompletionFoundation
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

  init(
    executablePath: URL,
    workspace: Workspace,
    shellService: ShellService,
    fileManager: FileManagerI,
    jrpcService: JRPCService)
  {
    self.workspace = workspace
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
    try await run(loggingErrorWith: "Failed to send JRPC notification to Github LSP Server: \(method)") {
      let transport = try await {
        if let initializingTransport { return initializingTransport }
        return try await initializedTransport.value
      }()

      let notification = JRPCNotification(method: method, params: params)
      let encoder = JSONEncoder()
      let jsonData = try encoder.encode(notification)
      try await transport.send(jsonData)
    }
  }

  func sendRequest<Response: Decodable>(
    _ method: String,
    params: JSON?,
    initializingTransport: StdioConnection? = nil)
    async throws -> Response
  {
    do {
      let result = try await sendRawRequest(method, params: params, initializingTransport: initializingTransport)
      let resultData = try JSONEncoder().encode(result)
      return try JSONDecoder().decode(Response.self, from: resultData)
    } catch let error as JRPCResponseError {
      if error.error.message == "Request was superseded by a new request" {
        // ignore
      } else {
        defaultLogger.error("Failed to send JRPC request to Github LSP Server: \(method)", error)
      }
      throw error
    } catch {
      defaultLogger.error("Failed to send JRPC request to Github LSP Server: \(method)", error)
      throw error
    }
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
    try await transport.send(jsonData)

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
    filesSharedWithServer.insert(uri)
  }

  func didChangeTextDocument(uri: String, version: Int, text: String) async throws {
    defaultLogger.trace("Document changed: \(uri)")
    let params = DidChangeTextDocumentParams(
      textDocument: TextDocumentIdentifier(uri: uri, version: version),
      contentChanges: [TextDocumentContentChangeEvent(text: text)])

    try await sendNotification("textDocument/didChange", params: .init(encoding: params))
    filesSharedWithServer.insert(uri)
  }

  func didSaveTextDocument(uri: String, version: Int, text: String?) async throws {
    defaultLogger.trace("Document saved: \(uri)")
    let params = DidSaveTextDocumentParams(
      textDocument: TextDocumentIdentifier(uri: uri, version: version),
      text: text)

    try await sendNotification("textDocument/didSave", params: .init(encoding: params))
    filesSharedWithServer.insert(uri)
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
    if !filesSharedWithServer.contains(uri) {
      // This can happen if we have not yet shared our files with the server and the completion request arrives early.
      // Ignore the request.
      return InlineCompletionList(items: [])
    }
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

  private var filesSharedWithServer = Set<String>()

  private var nextId = 1
  private var pendingRequests = [Int: CheckedContinuation<JSON.Value, Error>]()

  private let shellService: ShellService
  private let workspace: Workspace
  private let fileManager: FileManagerI
  private let jrpcService: JRPCService

  private func start() async throws -> StdioConnection {
    defaultLogger.trace("Starting Copilot language server...")
    defaultLogger.trace("Executable path: \(executablePath.path)")

    // Create transport with command
    let command = "\"\(executablePath.path)\" --stdio"
    defaultLogger.trace("Command: \(command)")

    let env = await shellService.env
    let transport = jrpcService.createConnection(
      command: command,
      env: env,
      pwd: nil,
      configuration: .init(
        // LSP protocol requires Content-Length header
        delimitation: .contentLength,
        logger: nil, // defaultLogger.subLogger(subsystem: "github-copilot-lsp-server")
      ))
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
        let stream = transport.receive()
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
      do {
        try await handle(request: request)
      } catch {
        // Respond with an internal error
        let response = JRPCResponse(
          id: request.id,
          result: nil,
          error: .init(code: -32603, message: error.localizedDescription, data: nil))

        do {
          let jsonData = try JSONEncoder().encode(response)
          let transport = try await initializedTransport.value
          try await transport.send(jsonData)
        } catch {
          defaultLogger.log("Failed to send response to server request: \(error)")
        }
      }
    }
  }

  private func handle(request: JRPCRequest) async throws {
    let method = request.method
    let params = request.params
    let id = request.id
    defaultLogger.log("Handling server request: \(method)")

    let response: JRPCResponse
    let httpConfiguration: HTTPConfiguration =
      if let copilotProxy = await shellService.env["GITHUB_COPILOT_PROXY"] {
        .init(proxy: copilotProxy, proxyStrictSSL: false)
      } else {
        .default
      }

    switch method {
    case "workspace/configuration":
      if
        let request = try? params?.decode(as: WorkspaceConfigurationRequestParameters.self),
        let data = try? WorkspaceConfigurationBuilder.buildResponse(for: request, httpConfiguration: httpConfiguration)
      {
        defaultLogger.log(" → Responding with \(request.items.count) configurations")
        response = JRPCResponse(id: id, result: data, error: nil)
      } else {
        defaultLogger.log(" → No items requested, responding with empty array")
        response = JRPCResponse(id: id, result: .array([]), error: nil)
      }

    case "copilot/watchedFiles":
      // Server is asking for watched files
      var files = workspace.files
      // Respond with the first 100 files, and send the rest with notifications.
      let chunk = files.removeFirst(n: 100)
      let params = DidChangeWatchedFilesNotificationParameters(
        workspaceUri: workspace.url.absoluteString,
        changes: chunk.map { .init(uri: $0.absoluteString, type: .created) })
      response = try JRPCResponse(id: id, result: .init(encoding: params), error: nil)
      filesSharedWithServer.formUnion(chunk.map(\.absoluteString))
      defaultLogger.log(" → Responding with \(files.count) files to watch")

      while !files.isEmpty {
        let chunk = files.removeFirst(n: 100)
        let params = DidChangeWatchedFilesNotificationParameters(
          workspaceUri: workspace.url.absoluteString,
          changes: chunk.map { .init(uri: $0.absoluteString, type: .created) })
        try await sendNotification(
          "workspace/didChangeWatchedFiles",
          params: .init(encoding: params))
        filesSharedWithServer.formUnion(chunk.map(\.absoluteString))
      }

    default:
      defaultLogger.log(" → Unknown request method \(method), responding with null")
      response = JRPCResponse(id: id, result: .null, error: nil)
    }

    do {
      let jsonData = try JSONEncoder().encode(response)
      let transport = try await initializedTransport.value
      try await transport.send(jsonData)
    } catch {
      defaultLogger.log("Failed to send response to server request: \(error)")
    }
  }

  // MARK: - LSP Initialize

  private func initialize(initializingTransport: StdioConnection) async throws {
    let params = InitializeParams(
      processId: Int(ProcessInfo.processInfo.processIdentifier),
      rootUri: workspace.root.path, // TODO? uri?
      rootPath: workspace.root.path,
      initializationOptions: [
        "editorInfo": .object(["name": "Xcode", "version": "26.0"]),
        "editorPluginInfo": .object(["name": "copilot-xcode", "version": "0.0.0"]),
        "copilotCapabilities": .object([
          "watchedFiles": .bool(workspace.root.path != "/"),
          "didChangeFeatureFlags": true,
          "stateDatabase": true,
        ]),
        "githubAppId": "",
      ],
      capabilities: ClientCapabilities(workspace: .init()),
      workspaceFolders: [
        WorkspaceFolder(uri: workspace.root.absoluteString, name: workspace.root.lastPathComponent),
      ])

    let result: InitializeResult = try await sendRequest(
      "initialize",
      params: .init(encoding: params),
      initializingTransport: initializingTransport)
    _ = result

    // Send initialized notification with empty object
    try await sendNotification("initialized", params: .object([:]), initializingTransport: initializingTransport)
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

extension Array {
  /// Removes and returns the first `n` elements of the array as a subsequence.
  mutating func removeFirst(n: Int) -> Array<Element>.SubSequence {
    let prefix = prefix(n)
    removeFirst(Swift.min(n, count))
    return prefix
  }
}
