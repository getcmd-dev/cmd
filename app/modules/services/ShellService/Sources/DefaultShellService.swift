// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation
import DependencyFoundation
import Foundation
import LoggingServiceInterface
import ShellServiceInterface
import Subprocess

// MARK: - DefaultShellService

import ThreadSafe

// MARK: - DefaultShellService

@ThreadSafe
final class DefaultShellService: ShellService {

  init() {
    loadZshEnvironmentInBackground()
  }

  public private(set) var env: [String: String] = [:]

  @discardableResult
  func run(
    _ command: String,
    cwd: String?,
    useInteractiveShell: Bool,
    body: SubprocessHandle? = nil)
    async throws -> CommandExecutionResult
  {
    let process = Process()
    process.launchPath = "/bin/zsh"
    if useInteractiveShell {
      process.environment = env
    }
    process.arguments = ["-c"] + [command]
    if let cwd {
      process.currentDirectoryPath = cwd
    }

    let stdoutData = Atomic(Data())
    let stderrData = Atomic(Data())
    let mergedData = Atomic(Data())

    let (stdoutHasCompleted, stdoutCompleted) = Future<Void, Never>.make()
    let (stderrHasCompleted, stderrCompleted) = Future<Void, Never>.make()

    let result = try await Subprocess.run(
      .path("/bin/zsh"),
      arguments: Arguments(["-c"] + [command]),
      environment: useInteractiveShell ? Environment.custom(env) : .inherit,
      workingDirectory: cwd.map { .init($0) })
    { execution, inputIO, outputIO, errorIO in
      let outputStream = outputIO.toDataStream
      let errorStream = errorIO.toDataStream
      body?(execution, inputIO, outputStream.eraseToStream(), errorStream.eraseToStream())

      Task {
        for await data in outputStream {
          stdoutData.mutate { $0.append(data) }
          mergedData.mutate { $0.append(data) }
        }
        stdoutCompleted(.success(()))
      }
      Task {
        for await data in errorStream {
          stderrData.mutate { $0.append(data) }
          mergedData.mutate { $0.append(data) }
        }
        stderrCompleted(.success(()))
      }
    }

    await stdoutHasCompleted.value
    await stderrHasCompleted.value

    return CommandExecutionResult(
      exitCode: result.terminationStatus.code,
      stdout: String(data: stdoutData.value, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
      stderr: String(data: stderrData.value, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
      mergedOutput: String(data: mergedData.value, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  private static func loadZshEnvironment(userEnv: [String: String]? = nil) async throws -> [String: String] {
    let result = try await Subprocess.run(
      .path("/bin/zsh"),
      arguments: Arguments(["-ilc", "printenv"]),
      environment: userEnv?.isEmpty == false ? Environment.custom(userEnv!) : .inherit)
    { _, _, outputIO, _ in
      var contents = ""
      for try await chunk in outputIO {
        let string = chunk.withUnsafeBytes { String(decoding: $0, as: UTF8.self) }
        contents += string
      }
      return contents
    }

    return result.value
      .split(separator: "\n")
      .reduce(into: [String: String]()) { result, line in
        let components = line.split(separator: "=", maxSplits: 1)
        guard components.count == 2 else { return }
        result[String(components[0])] = String(components[1])
      }
  }

  /// This can be moved to the initializer once https://github.com/swiftlang/swift/issues/80050 is fixed.
  private func loadZshEnvironmentInBackground() {
    Task.detached { [weak self] in
      self?.env = try await Self.loadZshEnvironment()
    }
  }

}

extension BaseProviding {
  public var shellService: ShellService {
    shared {
      DefaultShellService()
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

// Conform Subprocess types to ShellServiceInterface protocols,
// which are similar but allow to limit imports to consuming modules

extension Subprocess.StandardInputWriter: ShellServiceInterface.StandardInputWriter {
  public func write(_ string: String) async throws {
    _ = try await write(string, using: UTF8.self)
  }

}

extension Subprocess.Execution: ShellServiceInterface.Execution {
  public func tearDown() async {
    await teardown(using: [])
  }

  public func terminate() throws {
    try send(signal: .terminate)
  }
}

extension AsyncBufferSequence {
  var toDataStream: BroadcastedStream<Data> {
    let (stream, continuation) = AsyncStream<Data>.makeStream()

    Task {
      do {
        for try await bytes in self {
          let data = bytes.withUnsafeBytes { buffer in Data(buffer) }
          continuation.yield(data)
        }
        continuation.finish()
      } catch {
        defaultLogger.error("Error processing process' output", error)
        continuation.finish()
      }
    }

    return BroadcastedStream(replayStrategy: .replayAll, stream)
  }
}

extension TerminationStatus {
  var code: Int32 {
    switch self {
    case .exited(let code):
      code
    case .unhandledException(let code):
      code
    }
  }
}
