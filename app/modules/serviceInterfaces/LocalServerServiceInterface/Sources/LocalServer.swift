// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation

// MARK: - LocalServer

public protocol LocalServer: Sendable {
  func getRequest(path: String, onReceiveJSONData: (@Sendable (Data) -> Void)?) async throws -> Data
  func postRequest(path: String, data: Data, onReceiveJSONData: (@Sendable (Data) -> Void)?) async throws -> Data
}

extension LocalServer {

  public func getRequest(path: String) async throws -> Data? {
    try await getRequest(path: path, onReceiveJSONData: nil)
  }

  public func getRequest<Response: Decodable>(path: String) async throws -> Response {
    let data = try await getRequest(path: path, onReceiveJSONData: nil)
    return try decode(data)
  }

  public func postRequest(path: String, data: Data) async throws -> Data? {
    try await postRequest(path: path, data: data, onReceiveJSONData: nil)
  }

  public func postRequest<Response: Decodable>(path: String, data: Data) async throws -> Response {
    let data = try await postRequest(path: path, data: data, onReceiveJSONData: nil)
    if let err: SerializedError = try? decode(data) {
      throw APIError(
        statusCode: err.statusCode,
        localizedDescription: err.message,
        debugDescription: err.stack)
    }
    return try decode(data)
  }

  public func streamPostRequest(path: String, data: Data) -> AsyncThrowingStream<Data, Error> {
    let (stream, continuation) = AsyncThrowingStream<Data, Error>.makeStream()
    let task = Task {
      do {
        _ = try await postRequest(path: path, data: data) { data in
          continuation.yield(data)
        }
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
  var localServer: LocalServer { get }
}

// MARK: - APIError

public struct APIError: Error, Sendable, LocalizedError {
  let statusCode: Int
  let localizedDescription: String
  let debugDescription: String?

  public init(statusCode: Int, localizedDescription: String, debugDescription: String?) {
    self.statusCode = statusCode
    self.localizedDescription = localizedDescription
    self.debugDescription = debugDescription
  }

  public init(_ message: String) {
    self.init(statusCode: 500, localizedDescription: message, debugDescription: nil)
  }
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
