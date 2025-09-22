// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppEventServiceInterface
import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import DependencyFoundation
import Foundation
import FoundationInterfaces
import LocalServerServiceInterface
import LoggingServiceInterface
import SettingsServiceInterface

// MARK: - DefaultLocalServer

import ThreadSafe

// MARK: - DefaultLocalServer

// TODO: convert bad status code to error and throw.

@ThreadSafe
final class DefaultLocalServer: LocalServer {

  init(
    sharedUserDefaults: UserDefaultsI,
    appEventHandlerRegistry: AppEventHandlerRegistry,
    fileManager: FileManagerI)
  {
    self.sharedUserDefaults = sharedUserDefaults
    self.appEventHandlerRegistry = appEventHandlerRegistry
    self.fileManager = fileManager
    hasCopiedFiles = false
    applicationSupportPath = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(Bundle.main.hostAppBundleId).path

    let delegate = LocalServerDelegate()
    let configuration = URLSessionConfiguration.default
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.timeoutIntervalForRequest = 600 // 10mn for an entire request
    configuration.timeoutIntervalForResource = 600 // 10mn for an entire request
    session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    connectionStatus = .waitingOnConnection(.init { _ in })

    self.delegate = delegate
    delegate.owner = self

    Task {
      try await self.connect()
    }
  }

  let appEventHandlerRegistry: AppEventHandlerRegistry

  var serverConnection: URLSessionWebSocketTask?

  func getRequest(
    path: String,
    configure: (inout URLRequest) -> Void,
    onReceiveJSONData: (@Sendable (Data) -> Void)?)
    async throws -> Data
  {
    let port = try await connectionStatus.port
    guard let url = URL(string: "http://localhost:\(port)/\(path)") else {
      throw APIError("Invalid URL: http://localhost:\(port)/\(path)")
    }
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.timeoutInterval = 60
    configure(&request)

    let (data, response) = try await send(request: request, onReceiveJSONData: onReceiveJSONData)
    try assertIsSuccess(response: response, data: data)
    return data
  }

  func postRequest(
    path: String,
    data: Data,
    configure: (inout URLRequest) -> Void,
    onReceiveJSONData: (@Sendable (Data) -> Void)?)
    async throws -> Data
  {
    var path = path
    if path.starts(with: "/") {
      path = String(path.dropFirst())
    }
    let port = try await connectionStatus.port
    var request = URLRequest(url: URL(string: "http://localhost:\(port)/\(path)")!)
    request.httpMethod = "POST"
    request.timeoutInterval = 60
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    request.httpBody = data
    configure(&request)

    let (data, response) = try await send(request: request, onReceiveJSONData: onReceiveJSONData)
    try assertIsSuccess(response: response, data: data)
    return data
  }

  func handle(task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let handler = inflightTasks.removeValue(forKey: task) else {
      return
    }
    let response = task.response
    Task { @MainActor in
      if let error {
        defaultLogger.error("Task completed with error", error)
        handler.continuation.resume(throwing: error)
      } else if let response {
        handler.continuation.resume(returning: (handler.totalData, response))
      } else {
        assertionFailure("Task completed without response")
        handler.continuation.resume(throwing: URLError(.badServerResponse))
      }
    }
  }

  func handle(dataTask: URLSessionDataTask, didReceive data: Data) {
    // Immediately queue the handling of the data to ensure we are not blocking the URLSession delegate callback.
    pendingHandleDataTasks.queue {
      await Task.detached(priority: .userInitiated) { [weak self] in
        guard let self else { return }

        // TODO: Make this async, and serial.
        guard var handler = inflightTasks[dataTask] else {
          return
        }
        defer { self.inflightTasks[dataTask] = handler }

        handler.totalData.append(data)

        if let onReceiveJSONData = handler.onReceiveJSONData {
          handler.incompletedJSONData.append(data)
          let (jsonObjects, newImcompleteData) = handler.incompletedJSONData.parseJSONObjects()
          handler.incompletedJSONData = newImcompleteData ?? Data()

          for jsonObject in jsonObjects {
            onReceiveJSONData(jsonObject)
          }
        }
      }.value
    }
  }

  private struct TaskHandler: Sendable {
    let continuation: CheckedContinuation<(Data, URLResponse), Error>
    let onReceiveJSONData: (@Sendable (Data) -> Void)?
    /// Data received from the server that is not yet a complete JSON object.
    var incompletedJSONData = Data()
    /// All the data received from the server since the beginning of the task.
    var totalData = Data()
  }

  private enum ConnectionStatus: Sendable {
    case waitingOnConnection(Future<ConnectionResponse, Error>)
    case connected(port: Int)

    var port: Int {
      get async throws {
        switch self {
        case .connected(let port):
          port
        case .waitingOnConnection(let onConnection):
          try await onConnection.value.port
        }
      }
    }
  }

  private let pendingHandleDataTasks = TaskQueue<Void, Never>()

  private let fileManager: FileManagerI

  private let applicationSupportPath: String

  private let sharedUserDefaults: UserDefaultsI
  private var hasCopiedFiles: Bool

  private var inflightTasks: [URLSessionTask: TaskHandler] = [:]

  private let delegate: LocalServerDelegate

  private var connectionStatus: ConnectionStatus

  private let session: URLSession

  /// Connect to the server, and return the port where the server is running.
  private func connect() async throws {
    var onConnection: Future<ConnectionResponse, Error>.Promise?
    connectionStatus = .waitingOnConnection(.init { onConnection = $0 })

    do {
      try copyExecutableFiles()

      let mainPath = (applicationSupportPath as NSString).appendingPathComponent("launch-server.sh")

      // TODO: move to using the shell service.
      let process = Process()
      process.launchPath = "/bin/zsh"
      #if DEBUG
      // In debug, load the interactive shell to allow for local env parameters to be passed in.
      process.arguments = ["-ilc"] + ["'\(mainPath)' --attachTo \(getpid())"]
      #else
      let enableNetworkProxy = sharedUserDefaults.bool(forKey: .enableNetworkProxy)
      if enableNetworkProxy {
        // In release with network proxy enabled, load the interactive shell to allow for local env parameters to be passed in.
        process.arguments = ["-ilc"] + ["'\(mainPath)' --attachTo \(getpid())"]
      } else {
        process.arguments = ["-c"] + ["'\(mainPath)' --attachTo \(getpid())"]
      }
      #endif

      let stdout = Pipe()
      process.standardOutput = stdout
      let connectionResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
        ConnectionResponse,
        Error
      >) in
        let hasResponded = Atomic(false)

        Task {
          for await data in stdout.fileHandleForReading.dataStream {
            let hadAlreadyResponded = hasResponded.set(to: true)
            guard !hadAlreadyResponded else { return }
            if let response = try? JSONDecoder().decode(ConnectionResponse.self, from: data) {
              continuation.resume(returning: response)

              listenToExtension(port: response.port)
              sharedUserDefaults.set(response.port, forKey: UserDefaultKeys.localServerPort)
              defaultLogger.log("Local server started at port \(response.port)")
            }
          }
        }

        do {
          try process.run()
          Task.detached { [weak self] in
            process.waitUntilExit()
            if let self {
              // The server crashed or was killed, restart it.
              defaultLogger.error("Restarting server. This should not happen.")
              try await connect()
            }
          }
        } catch {
          let hadAlreadyResponded = hasResponded.set(to: true)
          guard !hadAlreadyResponded else {
            assertionFailure("Error running executable: \(error.localizedDescription)")
            return
          }
          continuation.resume(throwing: error)
        }
      }
      connectionStatus = .connected(port: connectionResult.port)
      onConnection?(.success(connectionResult))

    } catch {
      onConnection?(.failure(error))
      throw error
    }
  }

  private func copyExecutableFiles() throws {
    guard !hasCopiedFiles else {
      // Not re-copying the files over allows for the server to be hot-reloaded during development.
      // In production, there is no reason for those files to have changed since the app was launched.
      return
    }
    hasCopiedFiles = true
    let files = ["main.bundle.cjs.gz", "main.bundle.cjs.map", "launch-server.sh"]
    let filePaths = files.compactMap { resourceBundle.path(forResource: $0, ofType: nil) }

    guard filePaths.count == files.count else {
      assertionFailure("Application is missing required files")
      throw AppError(
        message: "Application is missing required files",
        debugDescription: "Failed to locate all files to copy. Could not start the local server.\nYou likely need to do File>Packages>Reset Package Cache and rebuild to resolve the issue.")
    }

    // Create application support directory if it doesn't exist
    try fileManager.createDirectory(atPath: applicationSupportPath, withIntermediateDirectories: true)

    try files.enumerated().forEach { idx, fileName in
      let destination = (applicationSupportPath as NSString).appendingPathComponent(fileName)
      let filePath = filePaths[idx]
      if fileManager.fileExists(atPath: destination) {
        try fileManager.removeItem(atPath: destination)
      }
      try fileManager.copyItem(atPath: filePath, toPath: destination)
      try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination)
    }
  }

  private func send(request: URLRequest, onReceiveJSONData: (@Sendable (Data) -> Void)?) async throws -> (Data, URLResponse) {
    let task = session.dataTask(with: request)

    return try await withTaskCancellationHandler(operation: {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, URLResponse), Error>) in
        let taskHandler = TaskHandler(
          continuation: continuation,
          onReceiveJSONData: onReceiveJSONData,
          incompletedJSONData: Data(),
          totalData: Data())
        inLock { state in
          state.inflightTasks[task] = taskHandler
        }

        task.resume()
      }
    }, onCancel: {
      task.cancel()
    })
  }

  private func assertIsSuccess(response: URLResponse, data: Data) throws {
    guard let httpURLResponse = response as? HTTPURLResponse else {
      throw APIError("Unexpected non-HTTP URL response. Data: \(String(data: data, encoding: .utf8) ?? "??")")
    }

    guard (200..<300).contains(httpURLResponse.statusCode) else {
      throw APIError("HTTP status code \(httpURLResponse.statusCode). Data: \(String(data: data, encoding: .utf8) ?? "??")")
    }
  }
}

extension FileHandle {
  public var dataStream: AsyncStream<Data> {
    let (stream, continuation) = AsyncStream<Data>.makeStream()

    readabilityHandler = { handle in
      let data = handle.availableData

      if data.isEmpty {
        handle.readabilityHandler = nil
        continuation.finish()
        return
      }

      continuation.yield(data)
    }

    return stream
  }
}

// MARK: - LocalServerDelegate

private final class LocalServerDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
  weak var owner: DefaultLocalServer?

  func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    Task {
      owner?.handle(dataTask: dataTask, didReceive: data)
    }
  }

  func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    Task {
      owner?.handle(task: task, didCompleteWithError: error)
    }
  }
}

// MARK: - ConnectionResponse

private struct ConnectionResponse: Decodable, Sendable {
  let port: Int
}

extension BaseProviding where
  Self: UserDefaultsProviding,
  Self: AppEventHandlerRegistryProviding,
  Self: FileManagerProviding
{
  public var localServer: LocalServer {
    shared {
      DefaultLocalServer(
        sharedUserDefaults: sharedUserDefaults,
        appEventHandlerRegistry: appEventHandlerRegistry,
        fileManager: fileManager)
    }
  }
}

private let resourceBundle = Bundle.module
