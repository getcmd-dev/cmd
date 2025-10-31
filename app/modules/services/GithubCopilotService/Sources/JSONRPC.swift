// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import JSONFoundation
import LoggingServiceInterface

// MARK: - JRPCRequest

struct JRPCRequest: Codable {
  init(id: Int, method: String, params: JSON.Value? = nil) {
    self.id = id
    self.method = method
    self.params = params
    jsonrpc = "2.0"
  }

  let jsonrpc: String
  let id: Int
  let method: String
  let params: JSON.Value?
}

// MARK: - JRPCMessage

enum JRPCMessage: Codable {
  case notification(JRPCNotification)
  case response(JRPCResponse)
  case request(JRPCRequest)

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: String.self)
    if container.allKeys.contains("method") {
      if container.allKeys.contains("id") {
        self = try .request(JRPCRequest(from: decoder))
      } else {
        self = try .notification(JRPCNotification(from: decoder))
      }
    } else {
      self = try .response(JRPCResponse(from: decoder))
    }
  }

  func encode(to encoder: Encoder) throws {
    switch self {
    case .notification(let notification):
      try notification.encode(to: encoder)
    case .response(let response):
      try response.encode(to: encoder)
    case .request(let request):
      try request.encode(to: encoder)
    }
  }
}

// MARK: - JRPCNotification

struct JRPCNotification: Codable {
  init(method: String, params: JSON? = nil) {
    self.method = method
    self.params = params
    jsonrpc = "2.0"
  }

  let jsonrpc: String
  let method: String
  let params: JSON?

}

// MARK: - JRPCResponse

struct JRPCResponse: Codable {
  let jsonrpc: String
  let id: Int
  let result: JSON.Value?
  let error: JRPCError?
}

// MARK: - JRPCError

struct JRPCError: Codable {
  let code: Int
  let message: String
  let data: JSON.Value?
}

// MARK: - JRPCResponseError

struct JRPCResponseError: Error {
  let error: JRPCError
}
