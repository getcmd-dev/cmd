// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Testing

@preconcurrency import Combine
import AppFoundation
import ConcurrencyFoundation
import Foundation
import FoundationInterfaces
import GithubCopilotServiceInterface
import JRPCServiceInterface
import JSONFoundation
import LoggingServiceInterface
import ShellServiceInterface
import SwiftTesting
@testable import GithubCopilotService

// MARK: - GithubCopilotServerTests

@Suite("GithubCopilotServer")
struct GithubCopilotServerTests {

  // MARK: - Initialization Tests

  @Test("Server initialization sends initialize request and initialized notification")
  func test_serverInitialization() async throws {
    // given
    let mockStdioConnection = MockStdioConnection()
    let mockJRPCService = MockJRPCService(onCreateConnection: { _, _, _, _ in
      mockStdioConnection
    })

    let shellService = MockShellService()
    let fileManager = MockFileManager(files: [:] as [String: String], directories: [])
    let executablePath = URL(fileURLWithPath: "/usr/local/bin/copilot")
    let workspaceRoot = URL(fileURLWithPath: "/Users/test/workspace")

    // Track the messages sent during initialization
    let sentMessages = Atomic<[Data]>([])
    mockStdioConnection.onSend = { data in
      sentMessages.mutate { $0.append(data) }
    }

    // Simulate server responses
    let expectInitializeRequest = expectation(description: "initialize request sent")
    let expectInitializedNotification = expectation(description: "initialized notification sent")

    mockStdioConnection.onSend = { data in
      sentMessages.mutate { $0.append(data) }

      // Parse the message
      if let message = try? Self.parseJRPCMessage(data) {
        switch message {
        case .request(let request):
          if request.method == "initialize" {
            expectInitializeRequest.fulfill()
            // Respond with initialize result
            Task {
              let response = """
              {
                "jsonrpc": "2.0",
                "id": \(request.id),
                "result": {
                  "capabilities": {}
                }
              }
              """
              mockStdioConnection.streamContinuation.yield(response.utf8Data)
            }
          }

        case .notification(let notification):
          if notification.method == "initialized" {
            expectInitializedNotification.fulfill()
          }

        default:
          break
        }
      }
    }

    // when
    let server = GithubCopilotServer(
      executablePath: executablePath,
      workspaceRoot: workspaceRoot,
      shellService: shellService,
      fileManager: fileManager,
      jrpcService: mockJRPCService)

    // then
    try await fulfillment(of: [expectInitializeRequest, expectInitializedNotification])

    // Verify we have at least 2 messages: initialize request and initialized notification
    #expect(sentMessages.value.count >= 2)

    // Verify the initialize request structure
    if
      sentMessages.value.count >= 1,
      let firstMessageData = try? Self.parseMessage(sentMessages.value[0])
    {
      firstMessageData.expectToMatch(
        """
        {
          "jsonrpc": "2.0",
          "method": "initialize",
          "params": {
            "capabilities": {},
            "processId": 0,
            "rootUri": "/Users/test/workspace",
            "workspaceFolders": [
              {
                "name": "workspace",
                "uri": "file:///Users/test/workspace"
              }
            ]
          }
        }
        """,
        ignoring: ["id", "params"]
      )
    }

    // Keep server alive
    _ = server
  }

  // MARK: - Authentication Tests

  @Test("checkStatus sends correct request and handles response")
  func test_checkStatus() async throws {
    // given
    let mockStdioConnection = MockStdioConnection()
    let mockJRPCService = MockJRPCService(onCreateConnection: { _, _, _, _ in
      mockStdioConnection
    })

    let shellService = MockShellService()
    let fileManager = MockFileManager(files: [:] as [String: String], directories: [])
    let executablePath = URL(fileURLWithPath: "/usr/local/bin/copilot")
    let workspaceRoot = URL(fileURLWithPath: "/Users/test/workspace")

    let checkStatusRequestId = Atomic<Int?>(nil)
    let expectCheckStatusRequest = expectation(description: "checkStatus request sent")

    mockStdioConnection.onSend = { data in
      if let message = try? Self.parseJRPCMessage(data) {
        switch message {
        case .request(let request):
          if request.method == "initialize" {
            // Respond to initialize
            let response = """
            {
              "jsonrpc": "2.0",
              "id": \(request.id),
              "result": {
                "capabilities": {}
              }
            }
            """
            mockStdioConnection.streamContinuation.yield(response.utf8Data)
          } else if request.method == "checkStatus" {
            checkStatusRequestId.set(to: request.id)
            expectCheckStatusRequest.fulfill()

            // Verify params is empty object
            #expect(request.params == .object([:]))

            // Respond with logged in status
            let response = """
            {
              "jsonrpc": "2.0",
              "id": \(request.id),
              "result": {
                "status": "OK",
                "user": "testuser"
              }
            }
            """
            mockStdioConnection.streamContinuation.yield(response.utf8Data)
          }

        default:
          break
        }
      }
    }

    let server = GithubCopilotServer(
      executablePath: executablePath,
      workspaceRoot: workspaceRoot,
      shellService: shellService,
      fileManager: fileManager,
      jrpcService: mockJRPCService)

    // Wait for initialization to complete
    _ = try await server.initializedTransport.value

    // when
    let result: CheckStatusResult = try await server.sendRequest("checkStatus", params: .object([:]))

    // then
    try await fulfillment(of: expectCheckStatusRequest)
    #expect(checkStatusRequestId.value != nil)
    #expect(result.status == .ok)
    #expect(result.user == "testuser")

    _ = server
  }

  @Test("signInInitiate sends correct request and handles response")
  func test_signInInitiate() async throws {
    // given
    let mockStdioConnection = MockStdioConnection()
    let mockJRPCService = MockJRPCService(onCreateConnection: { _, _, _, _ in
      mockStdioConnection
    })

    let shellService = MockShellService()
    let fileManager = MockFileManager(files: [:] as [String: String], directories: [])
    let executablePath = URL(fileURLWithPath: "/usr/local/bin/copilot")
    let workspaceRoot = URL(fileURLWithPath: "/Users/test/workspace")

    let signInInitiateRequestId = Atomic<Int?>(nil)
    let expectSignInInitiateRequest = expectation(description: "signInInitiate request sent")

    mockStdioConnection.onSend = { data in
      if let message = try? Self.parseJRPCMessage(data) {
        switch message {
        case .request(let request):
          if request.method == "initialize" {
            // Respond to initialize
            let response = """
            {
              "jsonrpc": "2.0",
              "id": \(request.id),
              "result": {
                "capabilities": {}
              }
            }
            """
            mockStdioConnection.streamContinuation.yield(response.utf8Data)
          } else if request.method == "signInInitiate" {
            signInInitiateRequestId.set(to: request.id)
            expectSignInInitiateRequest.fulfill()

            // Verify params is empty object
            #expect(request.params == .object([:]))

            // Respond with device flow
            let response = """
            {
              "jsonrpc": "2.0",
              "id": \(request.id),
              "result": {
                "status": "PromptUserDeviceFlow",
                "userCode": "ABCD-1234",
                "verificationUri": "https://github.com/login/device",
                "expiresIn": 900,
                "interval": 5
              }
            }
            """
            mockStdioConnection.streamContinuation.yield(response.utf8Data)
          }

        default:
          break
        }
      }
    }

    let server = GithubCopilotServer(
      executablePath: executablePath,
      workspaceRoot: workspaceRoot,
      shellService: shellService,
      fileManager: fileManager,
      jrpcService: mockJRPCService)

    // Wait for initialization to complete
    _ = try await server.initializedTransport.value

    // when
    let result: SignInInitiationResult = try await server.sendRequest("signInInitiate", params: .object([:]))

    // then
    try await fulfillment(of: expectSignInInitiateRequest)
    #expect(signInInitiateRequestId.value != nil)
    #expect(result.status == .promptUserDeviceFlow)
    #expect(result.userCode == "ABCD-1234")
    #expect(result.verificationUri == "https://github.com/login/device")
    #expect(result.expiresIn == 900)
    #expect(result.interval == 5)

    _ = server
  }

  @Test("signInConfirm sends correct request with userCode and handles response")
  func test_signInConfirm() async throws {
    // given
    let mockStdioConnection = MockStdioConnection()
    let mockJRPCService = MockJRPCService(onCreateConnection: { _, _, _, _ in
      mockStdioConnection
    })

    let shellService = MockShellService()
    let fileManager = MockFileManager(files: [:] as [String: String], directories: [])
    let executablePath = URL(fileURLWithPath: "/usr/local/bin/copilot")
    let workspaceRoot = URL(fileURLWithPath: "/Users/test/workspace")

    let signInConfirmRequestId = Atomic<Int?>(nil)
    let expectSignInConfirmRequest = expectation(description: "signInConfirm request sent")
    let expectedUserCode = "ABCD-1234"

    mockStdioConnection.onSend = { data in
      if let message = try? Self.parseJRPCMessage(data) {
        switch message {
        case .request(let request):
          if request.method == "initialize" {
            // Respond to initialize
            let response = """
            {
              "jsonrpc": "2.0",
              "id": \(request.id),
              "result": {
                "capabilities": {}
              }
            }
            """
            mockStdioConnection.streamContinuation.yield(response.utf8Data)
          } else if request.method == "signInConfirm" {
            signInConfirmRequestId.set(to: request.id)
            expectSignInConfirmRequest.fulfill()

            // Verify params contains userCode
            if
              let params = request.params,
              case .object(let obj) = params,
              case .string(let userCode) = obj["userCode"]
            {
              #expect(userCode == expectedUserCode)
            }

            // Respond with success
            let response = """
            {
              "jsonrpc": "2.0",
              "id": \(request.id),
              "result": {
                "status": "OK",
                "user": "testuser"
              }
            }
            """
            mockStdioConnection.streamContinuation.yield(response.utf8Data)
          }

        default:
          break
        }
      }
    }

    let server = GithubCopilotServer(
      executablePath: executablePath,
      workspaceRoot: workspaceRoot,
      shellService: shellService,
      fileManager: fileManager,
      jrpcService: mockJRPCService)

    // Wait for initialization to complete
    _ = try await server.initializedTransport.value

    // when
    let params = SignInConfirmParams(userCode: expectedUserCode)
    let result: SignInConfirmResult = try await server.sendRequest(
      "signInConfirm",
      params: JSON(encoding: params))

    // then
    try await fulfillment(of: expectSignInConfirmRequest)
    #expect(signInConfirmRequestId.value != nil)
    #expect(result.status == .ok)
    #expect(result.user == "testuser")

    _ = server
  }

  @Test("signOut sends correct request and handles response")
  func test_signOut() async throws {
    // given
    let mockStdioConnection = MockStdioConnection()
    let mockJRPCService = MockJRPCService(onCreateConnection: { _, _, _, _ in
      mockStdioConnection
    })

    let shellService = MockShellService()
    let fileManager = MockFileManager(files: [:] as [String: String], directories: [])
    let executablePath = URL(fileURLWithPath: "/usr/local/bin/copilot")
    let workspaceRoot = URL(fileURLWithPath: "/Users/test/workspace")

    let signOutRequestId = Atomic<Int?>(nil)
    let expectSignOutRequest = expectation(description: "signOut request sent")

    mockStdioConnection.onSend = { data in
      if let message = try? Self.parseJRPCMessage(data) {
        switch message {
        case .request(let request):
          if request.method == "initialize" {
            // Respond to initialize
            let response = """
            {
              "jsonrpc": "2.0",
              "id": \(request.id),
              "result": {
                "capabilities": {}
              }
            }
            """
            mockStdioConnection.streamContinuation.yield(response.utf8Data)
          } else if request.method == "signOut" {
            signOutRequestId.set(to: request.id)
            expectSignOutRequest.fulfill()

            // Verify params is empty object
            #expect(request.params == .object([:]))

            // Respond with success (empty object)
            let response = """
            {
              "jsonrpc": "2.0",
              "id": \(request.id),
              "result": {}
            }
            """
            mockStdioConnection.streamContinuation.yield(response.utf8Data)
          }

        default:
          break
        }
      }
    }

    let server = GithubCopilotServer(
      executablePath: executablePath,
      workspaceRoot: workspaceRoot,
      shellService: shellService,
      fileManager: fileManager,
      jrpcService: mockJRPCService)

    // Wait for initialization to complete
    _ = try await server.initializedTransport.value

    // when
    let result: JSON.Value = try await server.sendRawRequest("signOut", params: JSON.object([:] as [String: JSON.Value]))

    // then
    try await fulfillment(of: expectSignOutRequest)
    #expect(signOutRequestId.value != nil)
    #expect(result == .object([:]))

    _ = server
  }

  // MARK: - Helper Methods

  private static func parseMessage(_ data: Data) throws -> Data? {
    // LSP messages have Content-Length header followed by JSON
    guard let string = String(data: data, encoding: .utf8) else {
      return nil
    }

    // Split by double CRLF to separate headers from body
    let parts = string.components(separatedBy: "\r\n\r\n")
    guard parts.count >= 2 else {
      return nil
    }

    let body = parts[1]
    return body.data(using: .utf8)
  }

  private static func parseJRPCMessage(_ data: Data) throws -> JRPCMessage? {
    guard let jsonData = try parseMessage(data) else {
      return nil
    }
    return try JSONDecoder().decode(JRPCMessage.self, from: jsonData)
  }
}
