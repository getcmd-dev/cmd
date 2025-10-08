// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import Foundation
import LoggingServiceInterface

extension NSXPCConnection {
  /// Sends an asynchronous request to an XPC service and returns the result.
  ///
  /// This method creates a type-safe proxy to the remote XPC service, executes the provided handler
  /// with that proxy, and awaits the result. The operation includes automatic timeout handling and
  /// error propagation.
  ///
  /// - Parameters:
  ///   - connectionType: The protocol type that defines the XPC service interface. This is used to
  ///     cast the remote proxy to the correct type.
  ///   - timeoutNanoseconds: The maximum time to wait for the operation to complete, in nanoseconds.
  ///     Defaults to 1 second (1,000,000,000 nanoseconds). If the operation doesn't complete within
  ///     this time, a timeout error will be thrown.
  ///   - handler: An escaping closure that receives two parameters:
  ///     - A typed proxy to the remote XPC service conforming to `ConnectionProtocol`
  ///     - A `RacedContinuation` that must be resumed with either a result or an error to complete
  ///       the async operation
  ///
  /// - Returns: The output value of type `Output` produced by the handler's continuation.
  ///
  /// - Throws:
  ///   - `XPCError.invalidProxy` if the remote object proxy cannot be cast to the expected
  ///     `ConnectionProtocol` type
  ///   - Any error passed to the error handler when obtaining the remote proxy
  ///   - Timeout error if the operation doesn't complete within `timeoutNanoseconds`
  ///   - Any error thrown by resuming the continuation in the handler
  ///
  /// - Note: The handler is responsible for calling methods on the service proxy and resuming the
  ///   continuation with the result.
  ///
  /// Example usage:
  /// ```swift
  /// let result = try await connection.send(to: MyServiceProtocol.self) { service, continuation in
  ///   service.performOperation { result, error in
  ///     if let error = error {
  ///       continuation.resume(throwing: error)
  ///     } else {
  ///       continuation.resume(returning: result)
  ///     }
  ///   }
  /// }
  /// ```
  public func send<ConnectionProtocol, Output>(
    to _: ConnectionProtocol.Type,
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    _ handler: @escaping (ConnectionProtocol, RacedContinuation<Output, Error>) -> Void)
    async throws -> Output
  {
    try await withRacedThrowingContinuation { continuation in
      continuation.timeout(afterNanoseconds: timeoutNanoseconds)
      let proxy = self.remoteObjectProxyWithErrorHandler { error in
        defaultLogger.error("[XPC] Error getting remote proxy", error)
        continuation.resume(throwing: error)
      }

      guard let service = proxy as? ConnectionProtocol else {
        continuation.resume(throwing: XPCError.invalidProxy)
        return
      }
      handler(service, continuation)
    }
  }
}

extension Optional where Wrapped == NSXPCConnection {
  /// Sends an asynchronous request to an XPC service through an optional connection.
  ///
  /// This convenience method safely unwraps an optional `NSXPCConnection` and delegates to the
  /// non-optional `send` method. It provides a nil-safe way to interact with XPC connections that
  /// may not be established.
  ///
  /// - Parameters:
  ///   - connectionType: The protocol type that defines the XPC service interface. This is used to
  ///     cast the remote proxy to the correct type.
  ///   - timeoutNanoseconds: The maximum time to wait for the operation to complete, in nanoseconds.
  ///     Defaults to 1 second (1,000,000,000 nanoseconds). If the operation doesn't complete within
  ///     this time, a timeout error will be thrown.
  ///   - handler: An escaping closure that receives two parameters:
  ///     - A typed proxy to the remote XPC service conforming to `ConnectionProtocol`
  ///     - A `RacedContinuation` that must be resumed with either a result or an error to complete
  ///       the async operation
  ///
  /// - Returns: The output value of type `Output` produced by the handler's continuation.
  ///
  /// - Throws:
  ///   - `XPCError.notConnected` if the connection is `nil`
  ///   - `XPCError.invalidProxy` if the remote object proxy cannot be cast to the expected
  ///     `ConnectionProtocol` type
  ///   - Any error passed to the error handler when obtaining the remote proxy
  ///   - Timeout error if the operation doesn't complete within `timeoutNanoseconds`
  ///   - Any error thrown by resuming the continuation in the handler
  ///
  /// - Note: This method is particularly useful when working with lazily-initialized or potentially
  ///   disconnected XPC connections, as it provides clear error handling for the nil case.
  ///
  /// Example usage:
  /// ```swift
  /// var optionalConnection: NSXPCConnection?
  /// // ... connection may or may not be initialized
  ///
  /// let result = try await optionalConnection.send(to: MyServiceProtocol.self) { service, continuation in
  ///   service.performOperation { result, error in
  ///     if let error = error {
  ///       continuation.resume(throwing: error)
  ///     } else {
  ///       continuation.resume(returning: result)
  ///     }
  ///   }
  /// }
  /// ```
  public func send<ConnectionProtocol, Output>(
    to connectionType: ConnectionProtocol.Type,
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    _ handler: @escaping (ConnectionProtocol, RacedContinuation<Output, Error>) -> Void)
    async throws -> Output
  {
    guard let connection = self else {
      throw XPCError.notConnected
    }
    return try await connection.send(to: connectionType, timeoutNanoseconds: timeoutNanoseconds, handler)
  }
}
