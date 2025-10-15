// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation

// MARK: - LocalServer

public protocol LocalServer: Sendable {
  /// Performs a GET request to the specified path
  /// - Parameters:
  ///   - path: The URL path to send the GET request to
  ///   - configure: A closure that allows customization of the URLRequest before sending
  ///   - onReceiveJSONData: An optional closure called when JSON data is received during streaming
  ///   - idleTimeout: The number of seconds to wait without receiving data before timing out (default: 60s)
  /// - Returns: The response data from the server
  func getRequest(
    path: String,
    configure: (inout URLRequest) -> Void,
    onReceiveJSONData: (@Sendable (Data) -> Void)?,
    idleTimeout: TimeInterval)
    async throws -> Data
  /// Performs a POST request to the specified path with the provided data
  /// - Parameters:
  ///   - path: The URL path to send the POST request to
  ///   - data: The data to include in the request body
  ///   - configure: A closure that allows customization of the URLRequest before sending
  ///   - onReceiveJSONData: An optional closure called when JSON data is received during streaming
  ///   - idleTimeout: The number of seconds to wait without receiving data before timing out (default: 60s)
  /// - Returns: The response data from the server
  func postRequest(
    path: String,
    data: Data,
    configure: (inout URLRequest) -> Void,
    onReceiveJSONData: (@Sendable (Data) -> Void)?,
    idleTimeout: TimeInterval)
    async throws -> Data
}

extension LocalServer {

  /// Performs a GET request to the specified path without JSON streaming
  /// - Parameters:
  ///   - path: The URL path to send the GET request to
  ///   - configure: A closure that allows customization of the URLRequest before sending
  ///   - idleTimeout: The number of seconds to wait without receiving data before timing out (default: 60s)
  /// - Returns: The response data from the server, or nil if no data was received
  public func getRequest(path: String, configure: (inout URLRequest) -> Void = { _ in
  }, idleTimeout: TimeInterval = 60) async throws -> Data? {
    try await getRequest(path: path, configure: configure, onReceiveJSONData: nil, idleTimeout: idleTimeout)
  }

  /// Performs a GET request and decodes the response as a specific type
  /// - Parameters:
  ///   - path: The URL path to send the GET request to
  ///   - configure: A closure that allows customization of the URLRequest before sending
  ///   - idleTimeout: The number of seconds to wait without receiving data before timing out (default: 60s)
  /// - Returns: The decoded response object of the specified type
  public func getRequest<Response: Decodable>(path: String, configure: (inout URLRequest) -> Void = { _ in
  }, idleTimeout: TimeInterval = 60) async throws -> Response {
    let data = try await getRequest(path: path, configure: configure, onReceiveJSONData: nil, idleTimeout: idleTimeout)
    return try decode(data)
  }

  /// Performs a POST request to the specified path without JSON streaming
  /// - Parameters:
  ///   - path: The URL path to send the POST request to
  ///   - data: The data to include in the request body
  ///   - configure: A closure that allows customization of the URLRequest before sending
  ///   - idleTimeout: The number of seconds to wait without receiving data before timing out (default: 60s)
  /// - Returns: The response data from the server, or nil if no data was received
  public func postRequest(
    path: String,
    data: Data,
    configure: (inout URLRequest) -> Void = { _ in },
    idleTimeout: TimeInterval = 60)
    async throws -> Data?
  {
    try await postRequest(path: path, data: data, configure: configure, onReceiveJSONData: nil, idleTimeout: idleTimeout)
  }

  /// Performs a POST request and decodes the response as a specific type
  /// - Parameters:
  ///   - path: The URL path to send the POST request to
  ///   - data: The data to include in the request body
  ///   - configure: A closure that allows customization of the URLRequest before sending
  ///   - idleTimeout: The number of seconds to wait without receiving data before timing out (default: 60s)
  /// - Returns: The decoded response object of the specified type
  public func postRequest<Response: Decodable>(path: String, data: Data, configure: (inout URLRequest) -> Void = { _ in
  }, idleTimeout: TimeInterval = 60) async throws -> Response {
    let data = try await postRequest(
      path: path,
      data: data,
      configure: configure,
      onReceiveJSONData: nil,
      idleTimeout: idleTimeout)
    if let err: SerializedError = try? decode(data) {
      throw APIError(
        statusCode: err.statusCode,
        localizedDescription: err.message,
        debugDescription: err.stack)
    }
    return try decode(data)
  }

  /// Performs a POST request with streaming response data
  /// - Parameters:
  ///   - path: The URL path to send the POST request to
  ///   - data: The data to include in the request body
  ///   - configure: A closure that allows customization of the URLRequest before sending
  ///   - idleTimeout: The number of seconds to wait without receiving data before timing out (default: 60s)
  /// - Returns: An async stream that yields data chunks as they are received
  public func streamPostRequest(path: String, data: Data, configure: @Sendable @escaping (inout URLRequest) -> Void = { _ in
  }, idleTimeout: TimeInterval = 60) -> AsyncThrowingStream<Data, Error> {
    let (stream, continuation) = AsyncThrowingStream<Data, Error>.makeStream()
    let task = Task {
      do {
        _ = try await postRequest(path: path, data: data, configure: configure, onReceiveJSONData: { data in
          continuation.yield(data)
        }, idleTimeout: idleTimeout)
        continuation.finish()
      } catch {
        continuation.finish(throwing: error)
      }
    }
    continuation.onTermination = { _ in
      task.cancel()
    }
    return stream
  }

  private func decode<Response: Decodable>(_ data: Data?) throws -> Response {
    guard let data else {
      throw APIError("API response had no data")
    }
    return try JSONDecoder().decode(Response.self, from: data)
  }
}

// MARK: - LocalServerProviding

public protocol LocalServerProviding {
  /// Provides access to the local server instance
  /// - Returns: The local server instance for making HTTP requests
  var localServer: LocalServer { get }
}

// MARK: - APIError

public struct APIError: Error, Sendable, LocalizedError {
  /// Initializes an API error with detailed information
  /// - Parameters:
  ///   - statusCode: The HTTP status code associated with the error
  ///   - localizedDescription: A user-facing description of the error
  ///   - debugDescription: An optional detailed description for debugging purposes
  public init(statusCode: Int, localizedDescription: String, debugDescription: String?) {
    self.statusCode = statusCode
    self.localizedDescription = localizedDescription
    self.debugDescription = debugDescription
  }

  /// Initializes an API error with a message and default status code
  /// - Parameter message: The error message to display
  public init(_ message: String) {
    self.init(statusCode: 500, localizedDescription: message, debugDescription: nil)
  }

  let statusCode: Int
  let localizedDescription: String
  let debugDescription: String?

}

// MARK: - SerializedError

struct SerializedError: Decodable {
  let type = "error"
  let success: Bool
  let statusCode: Int
  let message: String
  let stack: String?

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    if try container.decode(String.self, forKey: "type") != "error" {
      throw APIError("Invalid error type")
    }
    success = try container.decode(Bool.self, forKey: "success")
    statusCode = try container.decode(Int.self, forKey: "statusCode")
    message = try container.decode(String.self, forKey: "message")
    stack = try container.decodeIfPresent(String.self, forKey: "stack")
  }
}
