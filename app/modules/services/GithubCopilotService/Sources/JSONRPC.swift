// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import LoggingServiceInterface

// MARK: - JSONRPCRequest

struct JSONRPCRequest: Encodable {
  init(id: Int, method: String, params: Any? = nil) {
    self.id = id
    self.method = method
    self.params = params.map { AnyCodable($0) }
  }

  init(id: Int, method: String, params: (some Encodable)?) {
    self.id = id
    self.method = method
    if let params {
      // Encode to JSON then decode to dictionary for proper nesting
      if
        let data = try? JSONEncoder().encode(params),
        let dict = try? JSONSerialization.jsonObject(with: data)
      {
        self.params = AnyCodable(dict)
      } else {
        self.params = nil
      }
    } else {
      self.params = nil
    }
  }

  let jsonrpc = "2.0"
  let id: Int
  let method: String
  let params: AnyCodable?

}

// MARK: - JSONRPCNotification

struct JSONRPCNotification: Encodable {
  init(method: String, params: Any? = nil) {
    self.method = method
    self.params = params.map { AnyCodable($0) }
  }

  init(method: String, params: (some Encodable)?) {
    self.method = method
    if let params {
      // Encode to JSON then decode to dictionary for proper nesting
      if
        let data = try? JSONEncoder().encode(params),
        let dict = try? JSONSerialization.jsonObject(with: data)
      {
        self.params = AnyCodable(dict)
      } else {
        self.params = nil
      }
    } else {
      self.params = nil
    }
  }

  let jsonrpc = "2.0"
  let method: String
  let params: AnyCodable?

}

// MARK: - JSONRPCResponse

struct JSONRPCResponse: Codable {
  let jsonrpc: String
  let id: Int?
  let result: AnyCodable?
  let error: JSONRPCError?
}

// MARK: - JSONRPCError

struct JSONRPCError: Codable {
  let code: Int
  let message: String
  let data: AnyCodable?
}

// MARK: - DataChannel

actor DataChannel {
  init(process: Process, inputPipe: Pipe, outputPipe: Pipe) {
    self.process = process
    self.inputPipe = inputPipe
    self.outputPipe = outputPipe
  }

  func write(_ data: Data) throws {
    inputPipe.fileHandleForWriting.write(data)
  }

  func readMessage() async throws -> Data? {
    // Read from output pipe until we have a complete message
    // LSP uses Content-Length header format
    while true {
      // Try to parse a message from buffer
      if let message = try parseMessage() {
        defaultLogger.log("Parsed complete message from buffer")
        return message
      }

      // Read more data asynchronously
      defaultLogger.log("Buffer has \(buffer.count) bytes, reading more data...")
      let handle = outputPipe.fileHandleForReading

      // Use background thread to avoid blocking the actor
      let newData = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            defaultLogger.log("Attempting to read from stdout...")
            guard let data = try handle.read(upToCount: 4096), !data.isEmpty else {
              defaultLogger.log("No data read from stdout (EOF)")
              continuation.resume(throwing: DataChannelError.processDied)
              return
            }
            defaultLogger.log("Read \(data.count) bytes from stdout")
            if let string = String(data: data, encoding: .utf8) {
              defaultLogger.log("Raw data: \(string)")
            } else {
              defaultLogger.log("Raw bytes (not UTF-8): \(data.map { String(format: "%02x", $0) }.joined(separator: " "))")
            }
            continuation.resume(returning: data)
          } catch {
            defaultLogger.log("Error reading from stdout: \(error)")
            continuation.resume(throwing: error)
          }
        }
      }

      buffer.append(newData)
    }
  }

  private let process: Process
  private let inputPipe: Pipe
  private let outputPipe: Pipe
  private var buffer = Data()

  private func parseMessage() throws -> Data? {
    // Look for "Content-Length: " header
    guard let headerEnd = buffer.range(of: "\r\n\r\n".data(using: .utf8)!) else {
      return nil
    }

    let headerData = buffer.subdata(in: 0..<headerEnd.lowerBound)
    guard let headerString = String(data: headerData, encoding: .utf8) else {
      throw DataChannelError.invalidHeader
    }

    // Parse Content-Length
    let lines = headerString.components(separatedBy: "\r\n")
    var contentLength: Int?

    for line in lines {
      if line.hasPrefix("Content-Length: ") {
        let lengthString = line.dropFirst("Content-Length: ".count)
        contentLength = Int(lengthString)
        break
      }
    }

    guard let length = contentLength else {
      throw DataChannelError.missingContentLength
    }

    let messageStart = headerEnd.upperBound
    let messageEnd = messageStart + length

    // Check if we have the full message
    guard buffer.count >= messageEnd else {
      return nil
    }

    let messageData = buffer.subdata(in: messageStart..<messageEnd)
    buffer.removeSubrange(0..<messageEnd)

    return messageData
  }
}

// MARK: - DataChannelError

enum DataChannelError: Error {
  case invalidHeader
  case missingContentLength
  case processDied
}

// MARK: - JSONRPCConnection

actor JSONRPCConnection {
  init(dataChannel: DataChannel) {
    self.dataChannel = dataChannel
  }

  func setMessageHandler(_ handler: @escaping (String, AnyCodable?) -> Void) {
    messageHandler = handler
  }

  func sendRequest(_ method: String, params: (some Encodable)?) async throws -> Data {
    let id = nextId
    nextId += 1

    let request =
      if let params {
        JSONRPCRequest(id: id, method: method, params: params)
      } else {
        JSONRPCRequest(id: id, method: method, params: nil as String?)
      }
    try await send(request)

    return try await withCheckedThrowingContinuation { continuation in
      pendingRequests[id] = continuation
    }
  }

  func sendNotification(_ method: String, params: (some Encodable)?) async throws {
    let notification =
      if let params {
        JSONRPCNotification(method: method, params: params)
      } else {
        JSONRPCNotification(method: method, params: nil as String?)
      }
    try await send(notification)
  }

  func startReading() {
    Task {
      defaultLogger.log("Starting message reading loop...")
      while true {
        do {
          defaultLogger.log("Waiting for message...")
          guard let messageData = try await dataChannel.readMessage() else {
            defaultLogger.log("Connection closed")
            break
          }

          defaultLogger.log("Received message data of size: \(messageData.count)")
          try await handleMessage(messageData)
        } catch {
          defaultLogger.log("Error reading message: \(error)")
          break
        }
      }
    }
  }

  private let dataChannel: DataChannel
  private var nextId = 1
  private var pendingRequests = [Int: CheckedContinuation<Data, Error>]()
  private var messageHandler: ((String, AnyCodable?) -> Void)?

  private func send(_ message: some Encodable) async throws {
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(message)

    let jsonString = String(data: jsonData, encoding: .utf8)!
    defaultLogger.log("Sending: \(jsonString)\n")

    let header = "Content-Length: \(jsonData.count)\r\n\r\n"
    var messageData = header.data(using: .utf8)!
    messageData.append(jsonData)

    try await dataChannel.write(messageData)
  }

  private func handleMessage(_ data: Data) async throws {
    let jsonString = String(data: data, encoding: .utf8) ?? "<invalid utf8>"
    defaultLogger.log("Received: \(jsonString)")

    let decoder = JSONDecoder()
    let response = try decoder.decode(JSONRPCResponse.self, from: data)

    if let id = response.id {
      // This is a response to our request
      if let continuation = pendingRequests.removeValue(forKey: id) {
        if let error = response.error {
          continuation.resume(throwing: JSONRPCResponseError(error: error))
        } else if let result = response.result {
          let resultData = try JSONEncoder().encode(result)
          continuation.resume(returning: resultData)
        } else {
          continuation.resume(returning: Data())
        }
      }
    } else {
      // This is a notification from the server
      if
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let method = jsonObject["method"] as? String
      {
        let params = jsonObject["params"].map { AnyCodable($0) }
        messageHandler?(method, params)
      }
    }
  }
}

// MARK: - JSONRPCResponseError

struct JSONRPCResponseError: Error {
  let error: JSONRPCError
}
