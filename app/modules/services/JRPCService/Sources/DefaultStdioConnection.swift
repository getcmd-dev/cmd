// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import JRPCServiceInterface
import LoggingServiceInterface

// MARK: - DefaultStdioConnection

actor DefaultStdioConnection: StdioConnection {
  init(command: String, env: [String: String], pwd: String?, configuration: STDIOConfiguration) {
    self.command = command

    self.env = env
    self.pwd = pwd

    delimitation = configuration.delimitation
    logger = configuration.logger

    let (stream, continuation) = AsyncThrowingStream<Data, Error>.makeStream()
    stdoutStream = stream
    stdoutContinuation = continuation
  }

  struct Connection: Sendable {
    let process: Process
    let stdinWriter: @Sendable (Data) throws -> Void
  }

  static let newLine = Data("\n".utf8)

  var disconnectionHandler: (@Sendable ((any Error)?) -> Void)?

  func onDisconnection(_ disconnectionHandler: @escaping @Sendable ((any Error)?) -> Void) {
    self.disconnectionHandler = disconnectionHandler
  }

  func disconnect() async {
    cancellable = nil
    disconnectionHandler?(nil)
  }

  func send(_ data: Data) async throws {
    guard let connection else {
      throw AppError("Not connected")
    }
    logger?.trace("stdio sending data: \(String(data: data, encoding: .utf8) ?? "nil")\n")
    try connection.stdinWriter(data)
  }

  func writeLog(data: Data) {
    let logPath = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Downloads")
      .appendingPathComponent("cmd.jrpc.jsonl")

    if FileManager.default.fileExists(atPath: logPath.path) {
      if let fileHandle = try? FileHandle(forWritingTo: logPath) {
        fileHandle.seekToEndOfFile()
        fileHandle.write(data)
        try? fileHandle.close()
      }
    } else {
      try? data.write(to: logPath, options: .atomic)
    }
  }

  nonisolated func receive() -> AsyncThrowingStream<Data, any Error> {
    stdoutStream
  }

  func connect() async throws {
    let (promise, continuation) = Future<Connection, Error>.make()
    let logger = logger

    let process = Process()
    // In MacOS, zsh is the default since macOS Catalina 10.15.7. We can safely assume it is available.
    process.launchPath = "/bin/zsh"
    process.arguments = ["-c"] + [command]
    process.environment = env

    // Input/output
    let stdin = Pipe()
    let stdout = Pipe()
    let stderr = Pipe()
    process.standardInput = stdin
    process.standardOutput = stdout
    process.standardError = stderr
    if let pwd {
      process.currentDirectoryPath = pwd
    }
    let stderrData = Atomic(Data())

    cancellable = AnyCancellable {
      // Ensures that the process is terminated when the Transport is de-referenced.
      if process.isRunning {
        process.terminate()
      }
    }

    Task { [weak self] in
      for await data in stdout.fileHandleForReading.dataStream.jsonStream {
        logger?.trace("stdio received data: \(String(data: data, encoding: .utf8) ?? "nil")")
        self?.stdoutContinuation.yield(data)
      }
      self?.stdoutContinuation.finish()
    }

    Task {
      for await data in stderr.fileHandleForReading.dataStream {
        stderrData.mutate {
          $0.append(data)
          // only keep last 4KB
          $0 = $0.suffix(4096)
        }
        logger?.error("Stdio stderr: \(String(data: data, encoding: .utf8) ?? "nil")")
      }
    }

    let isTerminated = Atomic(false)
    process.terminationHandler = { process in
      isTerminated.set(to: true)
      let errorStr = String(data: stderrData.value, encoding: .utf8)

      logger?.trace("Stdio process terminated with exit code \(process.terminationStatus). Stderr: \(errorStr ?? "nil")")
      Task {
        await self.closeConnection(to: process, stderr: stderr)
      }
    }

    do {
      try process.launchThrowably()
      let delimitation = delimitation

      continuation(.success(Connection(
        process: process,
        stdinWriter: { data in
          guard !isTerminated.value else {
            throw AppError("Process has terminated")
          }
          let dataToSend: Data

          switch delimitation {
          case .newLine:
            dataToSend = data + Self.newLine

          case .contentLength:
            let header = "Content-Length: \(data.count)\r\n\r\n"
            dataToSend = Data(header.utf8) + data

          case .none:
            dataToSend = data
          }
          logger?.trace("stdio sending data: `\(String(data: dataToSend, encoding: .utf8) ?? "nil")`\n")
          stdin.fileHandleForWriting.write(dataToSend)
        })))
    } catch {
      logger?.error("Error while establishing Stdio connection", error)
      continuation(.failure(error))
    }
    connection = try await promise.value
  }

  private let env: [String: String]?
  private let pwd: String?

  private let delimitation: STDIODelimitation
  private let logger: Logger?

  private let stdoutStream: AsyncThrowingStream<Data, Error>
  private let stdoutContinuation: AsyncThrowingStream<Data, Error>.Continuation

  private let command: String
  private var connection: Connection?
  private var cancellable: AnyCancellable?

  private func closeConnection(to process: Process, stderr: Pipe) {
    connection = nil
    let exitCode = process.terminationStatus
    if exitCode != 0 {
      if
        let data = (try? stderr.fileHandleForReading.readToEnd()),
        let err = String(data: data, encoding: .utf8)
      {
        logger?.log("Stdio connection terminated. Stderr:\n\(data)")
        disconnectionHandler?(AppError(err))
      } else {
        logger?.log("Stdio connection terminated")
        disconnectionHandler?(AppError("Stdio connection terminated with exit code \(exitCode)"))
      }
    }
    logger?.log("Stdio connection terminated with exit code 0")
  }
}

#if os(macOS)
extension Process {
  /// Launches process.
  ///
  /// - throws: CommandError.inAccessibleExecutable if command could not be executed.
  public func launchThrowably() throws {
    #if !os(macOS)
    guard Files.isExecutableFile(atPath: executableURL!.path) else {
      throw CommandError.inAccessibleExecutable(path: executableURL!.lastPathComponent)
    }
    #endif
    do {
      if #available(OSX 10.13, *) {
        try run()
      } else {
        launch()
      }
    } catch CocoaError.fileNoSuchFile {
      if #available(OSX 10.13, *) {
        throw CommandError.inAccessibleExecutable(path: self.executableURL!.lastPathComponent)
      } else {
        throw CommandError.inAccessibleExecutable(path: launchPath!)
      }
    }
  }

  /// Waits until process is finished.
  ///
  /// - throws: `CommandError.returnedErrorCode(command: String, errorcode: Int)`
  ///   if the exit code is anything but 0.
  public func finish() throws {
    /// The full path to the executable + all arguments, each one quoted if it contains a space.
    func commandAsString() -> String {
      let path: String =
        if #available(OSX 10.13, *) {
          self.executableURL?.path ?? ""
        } else {
          launchPath ?? ""
        }
      return (arguments ?? []).reduce(path) { (acc: String, arg: String) in
        acc + " " + (arg.contains(" ") ? ("\"" + arg + "\"") : arg)
      }
    }
    waitUntilExit()
    guard terminationStatus == 0 else {
      throw CommandError.returnedErrorCode(command: commandAsString(), errorcode: Int(terminationStatus))
    }
  }
}
#endif

// MARK: - CommandError

/// Error type for commands.
enum CommandError: Error, Equatable {
  /// Exit code was not zero.
  case returnedErrorCode(command: String, errorcode: Int)

  /// Command could not be executed.
  case inAccessibleExecutable(path: String)

  /// Exit code for this error.
  public var errorcode: Int {
    switch self {
    case .returnedErrorCode(_, let code):
      code
    case .inAccessibleExecutable:
      127 // according to http://tldp.org/LDP/abs/html/exitcodes.html
    }
  }
}

// MARK: CustomStringConvertible

extension CommandError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .inAccessibleExecutable(let path):
      "Could not execute file at path '\(path)'."
    case .returnedErrorCode(let command, let code):
      "Command '\(command)' returned with error code \(code)."
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

extension AsyncStream<Data> {
  /// Given a stream of Data that represents valid JSON objects, but that might be received over several chunks,
  /// or concatenated within the same chunk, return a stream of Data objects, each representing a valid JSON object.
  public var jsonStream: AsyncStream<Data> {
    let (stream, continuation) = AsyncStream<Data>.makeStream()
    Task {
      var truncatedData = Data()
      for await data in self {
        truncatedData.append(data)
        let (jsonObjects, newTruncatedData) = truncatedData.parseJSONObjects()
        truncatedData = newTruncatedData ?? Data()

        for jsonObject in jsonObjects {
          continuation.yield(jsonObject)
        }
      }
      continuation.finish()
    }
    return stream
  }
}

extension Data {

  /// Given a Data object that represents one or several valid JSON objects concatenated together, with the last one possibly truncated,
  /// return a list of Data objects, each representing a valid JSON object, as well as the optional truncated data.
  func parseJSONObjects() -> (objects: [Data], truncatedData: Data?) {
    var objects = [Data]()
    var isEscaping = false
    var isInString = false

    var openBraceCount = 0
    var currentChunkStartIndex: Int? = 0

    for (idx, byte) in enumerated() {
      if isEscaping {
        isEscaping = false
        continue
      }

      if byte == Self.escape {
        isEscaping = true
        continue
      }

      if byte == Self.quote {
        isInString = !isInString
        continue
      }

      if !isInString {
        if byte == Self.openBrace {
          if openBraceCount == 0 {
            currentChunkStartIndex = idx
          }
          openBraceCount += 1
        } else if byte == Self.closeBrace {
          openBraceCount -= 1

          if openBraceCount == 0, let startIndex = currentChunkStartIndex {
            let object = self[self.startIndex.advanced(by: startIndex) ..< self.startIndex.advanced(by: idx + 1)]
            objects.append(object)
            currentChunkStartIndex = nil
          }
        }
      }
    }

    let truncatedData: Data? =
      if let lastChunkStartIndex = currentChunkStartIndex {
        self[startIndex.advanced(by: lastChunkStartIndex) ..< startIndex.advanced(by: count)]
      } else {
        nil
      }

    return (objects: objects, truncatedData: truncatedData)
  }

  private static let openBrace = UInt8(ascii: "{")
  private static let closeBrace = UInt8(ascii: "}")
  private static let quote = UInt8(ascii: "\"")
  private static let escape = UInt8(ascii: "\\")

}
