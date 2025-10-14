// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import Foundation
#if DEBUG
public typealias LocalServerResponse = Data

public final class MockLocalServer: LocalServer {

  public init() { }

  public var onGetRequest: @Sendable (_ path: String, _ onReceiveJSONData: (@Sendable (Data) -> Void)?) async throws
    -> LocalServerResponse
  {
    get { _onGetRequest.value }
    set { _onGetRequest.mutate { $0 = newValue } }
  }

  public var onPostRequest: @Sendable (
    _ path: String,
    _ data: Data,
    _ onReceiveJSONData: (@Sendable (Data) -> Void)?)
    async throws -> LocalServerResponse
  {
    get { _onPostRequest.value }
    set { _onPostRequest.mutate { $0 = newValue } }
  }

  public func getRequest(
    path: String,
    configure _: (inout URLRequest) -> Void,
    onReceiveJSONData: (@Sendable (Data) -> Void)?,
    idleTimeout _: TimeInterval)
    async throws -> LocalServerResponse
  {
    try await throwingWhenCancelled(onReceiveJSONData) { onReceiveJSONData in
      try await self.onGetRequest(path, onReceiveJSONData)
    }
  }

  public func postRequest(
    path: String,
    data: Data,
    configure _: (inout URLRequest) -> Void,
    onReceiveJSONData: (@Sendable (Data) -> Void)?,
    idleTimeout _: TimeInterval)
    async throws -> LocalServerResponse
  {
    try await throwingWhenCancelled(onReceiveJSONData) { onReceiveJSONData in
      try await self.onPostRequest(path, data, onReceiveJSONData)
    }
  }

  private let _onGetRequest =
    Atomic<@Sendable (_ path: String, _ onReceiveJSONData: (@Sendable (Data) -> Void)?) async throws -> LocalServerResponse>
  { _, _ in
    throw URLError(.badServerResponse)
  }

  private let _onPostRequest =
    Atomic<
      @Sendable (_ path: String, _ data: Data, _ onReceiveJSONData: (@Sendable (Data) -> Void)?) async throws
        -> LocalServerResponse,
    > { _, _, _ in
      throw URLError(.badServerResponse)
    }

  /// Wraps the provided stub in one that will throw and stop send data chunk if the task is cancelled.
  private func throwingWhenCancelled(
    _ onReceiveJSONData: (@Sendable (Data) -> Void)?,
    _ sendRequest: @escaping @Sendable (_ onReceiveJSONData: (@Sendable (Data) -> Void)?) async throws -> LocalServerResponse)
    async throws -> LocalServerResponse
  {
    enum State {
      case initial
      case pending(CheckedContinuation<LocalServerResponse, Error>)
      case completed(Result<LocalServerResponse, Error>)
    }

    let state = Atomic<State>(.initial)
    // Resume the continuation if this has not been done already.
    let resume: @Sendable (Result<LocalServerResponse, Error>) -> Void = { result in
      let continuation: CheckedContinuation<LocalServerResponse, Error>? = state.mutate { state in
        switch state {
        case .initial:
          state = .completed(result)
          return nil

        case .pending(let continuation):
          state = .completed(result)
          return continuation

        case .completed:
          return nil
        }
      }
      continuation?.resume(with: result)
    }

    return try await withTaskCancellationHandler(operation: {
      try await withCheckedThrowingContinuation { continuation in
        let result: Result<LocalServerResponse, Error>? = state.mutate { state in
          switch state {
          case .initial:
            state = .pending(continuation)
            return nil

          case .pending:
            fatalError("invalid state, continuation set twice.")

          case .completed(let result):
            return result
          }
        }
        if let result {
          continuation.resume(with: result)
        }

        Task {
          do {
            let value = try await sendRequest { data in
              if case .completed = state.value {
                // Do not send the data chunk if the task has already completed.
              } else {
                onReceiveJSONData?(data)
              }
            }
            resume(.success(value))
          } catch {
            resume(.failure(error))
          }
        }
      }
    }, onCancel: {
      resume(.failure(CancellationError()))
    })
  }

}
#endif
