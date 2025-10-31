// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ConcurrencyFoundation
import Foundation
import ThreadSafe

#if DEBUG
@ThreadSafe
public final class MockStdioConnection: StdioConnection {
  public init() {
    let (stream, streamContinuation) = AsyncThrowingStream<Data, Swift.Error>.makeStream()
    self.stream = stream
    self.streamContinuation = streamContinuation
  }

  public var onConnect: (@Sendable () async throws -> Void) = { }
  public var onDisconnect: (@Sendable () async -> Void) = { }
  public var onSend: (@Sendable (Data) async throws -> Void) = { _ in }

  public func connect() async throws {
    try await onConnect()
  }

  public func disconnect() async {
    await onDisconnect()
  }

  public func send(_ data: Data) async throws {
    try await onSend(data)
  }

  public func receive() -> AsyncThrowingStream<Data, Swift.Error> {
    stream
  }

  public func onDisconnection(_ disconnectionHandler: @escaping @Sendable (Error?) -> Void) async {
    self.disconnectionHandler = disconnectionHandler
  }

  private let stream: AsyncThrowingStream<Data, Swift.Error>
  private let streamContinuation: AsyncThrowingStream<Data, Swift.Error>.Continuation

  private var disconnectionHandler: (@Sendable (Error?) -> Void)?

}

public final class MockJRPCService: JRPCService {
  public init(
    onCreateConnection: @escaping @Sendable (String, [String: String], String?, STDIODelimitation)
      -> StdioConnection = { _, _, _, _ in MockStdioConnection() })
  {
    self.onCreateConnection = onCreateConnection
  }

  public func createConnection(
    command: String,
    env: [String: String],
    pwd: String?,
    delimitation: STDIODelimitation)
    -> StdioConnection
  {
    onCreateConnection(command, env, pwd, delimitation)
  }

  private let onCreateConnection: @Sendable (String, [String: String], String?, STDIODelimitation) -> StdioConnection

}
#endif
