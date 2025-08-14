// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ExtensionEventsInterface
import Foundation
import LoggingServiceInterface

extension DefaultLocalServer {

  func listenToExtension(port: Int) {
    serverConnection?.cancel()
    serverConnection = nil

    // Start a web socket connection to the local server that will relay messages to the extension
    guard let url = URL(string: "ws://localhost:\(port)") else {
      defaultLogger.error("Failed to create URL for web socket connection.")
      return
    }
    let webSocket = URLSession.shared.webSocketTask(with: url)
    serverConnection = webSocket

    handleReceptionOfNextMessages()
    webSocket.resume()
  }

  private func handleReceptionOfNextMessages() {
    guard let webSocket = serverConnection else { return }

    webSocket.receive { [weak self] result in
      Task {
        guard let self else { return }
        self.handleReceptionOfNextMessages()
        self.handleReception(of: result)
      }
    }
  }

  private func handleReception(of message: Result<URLSessionWebSocketTask.Message, any Error>) {
    switch message {
    case .success(let message):
      switch message {
      case .string(let message):
        let data = message.utf8Data
        handleReception(of: data)

      case .data(let data):
        defaultLogger.log("Received data: \(data)")
        handleReception(of: data)

      @unknown default:
        defaultLogger.error("Received unknown message type \(message)")
      }

    case .failure(let error):
      defaultLogger.error("Failed to receive message: \(error)")
    }
  }

  private func handleReception(of data: Data) {
    do {
      let request = try JSONDecoder().decode(ExecuteCommandRequest.self, from: data)
      let event = ExecuteExtensionRequestEvent(
        command: request.command,
        id: request.id,
        data: data)
      { [weak self] result in
        Task {
          guard let self else { return }
          do {
            let responseData = try JSONEncoder().encode(ExecuteCommandResponse(
              command: request.command,
              id: request.id,
              result: result))
            try await self.serverConnection?.send(.data(responseData))
          } catch {
            defaultLogger.error("Failed to encode response: \(error)")
          }
        }
      }
      Task {
        await self.appEventHandlerRegistry.handle(event: event)
      }
    } catch {
      defaultLogger.error("Failed to decode message: \(error)")
    }
  }
}

// MARK: - ExecuteCommandRequest

struct ExecuteCommandRequest: Decodable {
  let command: String
  let id: String
}

// MARK: - ExecuteCommandResponse

struct ExecuteCommandResponse: Encodable {
  let command: String
  let id: String
  let result: Result<any Encodable & Sendable, Error>

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: String.self)
    try container.encode(command, forKey: "command")
    try container.encode(id, forKey: "id")
    switch result {
    case .success(let value):
      try container.encode(value, forKey: "data")
    case .failure(let error):
      try container.encode(error.localizedDescription, forKey: "error")
    }
  }
}
