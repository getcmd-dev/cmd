// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Testing

import AppFoundation
import CodeCompletionFoundation
@preconcurrency import Combine
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
      workspace: FrozenWorkspace(url: workspaceRoot, root: workspaceRoot, files: []),
      shellService: shellService,
      fileManager: fileManager,
      jrpcService: mockJRPCService)

    // then
    try await fulfillment(of: [expectInitializeRequest, expectInitializedNotification])

    // Verify we have at least 2 messages: initialize request and initialized notification
    #expect(sentMessages.value.count >= 2)

    // Verify the initialize request structure
    if
      let firstMessageData = sentMessages.value.first
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
        ignoring: ["id", "params"])
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
      workspace: FrozenWorkspace(url: workspaceRoot, root: workspaceRoot, files: []),
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
      workspace: FrozenWorkspace(url: workspaceRoot, root: workspaceRoot, files: []),
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
      workspace: FrozenWorkspace(url: workspaceRoot, root: workspaceRoot, files: []),
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
      workspace: FrozenWorkspace(url: workspaceRoot, root: workspaceRoot, files: []),
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

  // MARK: - Server Request Handling Tests

  @Test("workspace/configuration request is handled correctly")
  func test_workspaceConfigurationRequest() async throws {
    // given
    let mockStdioConnection = MockStdioConnection()
    let mockJRPCService = MockJRPCService(onCreateConnection: { _, _, _, _ in
      mockStdioConnection
    })

    let shellService = MockShellService()
    let fileManager = MockFileManager(files: [:] as [String: String], directories: [])
    let executablePath = URL(fileURLWithPath: "/usr/local/bin/copilot")
    let workspaceRoot = URL(fileURLWithPath: "/Users/test/workspace")

    let expectConfigurationResponse = expectation(description: "configuration response sent")
    let responseData = Atomic<Data?>(nil)

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
          }

        case .response(let response):
          // This is the response to our workspace/configuration request
          responseData.set(to: data)
          expectConfigurationResponse.fulfill()

        default:
          break
        }
      }
    }

    let server = GithubCopilotServer(
      executablePath: executablePath,
      workspace: FrozenWorkspace(url: workspaceRoot, root: workspaceRoot, files: []),
      shellService: shellService,
      fileManager: fileManager,
      jrpcService: mockJRPCService)

    // Wait for initialization to complete
    _ = try await server.initializedTransport.value

    // when
    // Simulate the server sending a workspace/configuration request
    let configRequest = """
      {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "workspace/configuration",
        "params": {
          "items": []
        }
      }
      """
    mockStdioConnection.streamContinuation.yield(configRequest.utf8Data)

    // then
    try await fulfillment(of: expectConfigurationResponse)

    let response = try #require(responseData.value)
    let parsedResponse = try JSONDecoder().decode(JRPCResponse.self, from: response)
    #expect(parsedResponse.id == 1)
    #expect(parsedResponse.error == nil)

    _ = server
  }

  @Test("copilot/watchedFiles request with less than 100 files")
  func test_watchedFilesWithFewFiles() async throws {
    // given
    let mockStdioConnection = MockStdioConnection()
    let mockJRPCService = MockJRPCService(onCreateConnection: { _, _, _, _ in
      mockStdioConnection
    })

    let shellService = MockShellService()
    let fileManager = MockFileManager(files: [:] as [String: String], directories: [])
    let executablePath = URL(fileURLWithPath: "/usr/local/bin/copilot")
    let workspaceRoot = URL(fileURLWithPath: "/Users/test/workspace")

    // Create a workspace with 50 files
    let files = (0..<50).map { URL(fileURLWithPath: "/Users/test/workspace/file\($0).swift") }

    let expectWatchedFilesResponse = expectation(description: "watchedFiles response sent")
    let responseData = Atomic<Data?>(nil)

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
          }

        case .response(let response):
          // This is the response to our copilot/watchedFiles request
          if response.id == 1 {
            responseData.set(to: data)
            expectWatchedFilesResponse.fulfill()
          }

        default:
          break
        }
      }
    }

    let server = GithubCopilotServer(
      executablePath: executablePath,
      workspace: FrozenWorkspace(url: workspaceRoot, root: workspaceRoot, files: files),
      shellService: shellService,
      fileManager: fileManager,
      jrpcService: mockJRPCService)

    // Wait for initialization to complete
    _ = try await server.initializedTransport.value

    // when
    // Simulate the server sending a copilot/watchedFiles request
    let watchedFilesRequest = """
      {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "copilot/watchedFiles",
        "params": {}
      }
      """
    mockStdioConnection.streamContinuation.yield(watchedFilesRequest.utf8Data)

    // then
    try await fulfillment(of: expectWatchedFilesResponse)

    let response = try #require(responseData.value)
    let parsedResponse = try JSONDecoder().decode(JRPCResponse.self, from: response)
    #expect(parsedResponse.id == 1)
    #expect(parsedResponse.error == nil)

    // Verify the response contains the files
    if
      case .object(let resultObj) = parsedResponse.result,
      case .array(let changes) = resultObj["changes"]
    {
      #expect(changes.count == 50)
    }

    _ = server
  }

  @Test("copilot/watchedFiles request with more than 100 files sends notifications")
  func test_watchedFilesWithManyFiles() async throws {
    // given
    let mockStdioConnection = MockStdioConnection()
    let mockJRPCService = MockJRPCService(onCreateConnection: { _, _, _, _ in
      mockStdioConnection
    })

    let shellService = MockShellService()
    let fileManager = MockFileManager(files: [:] as [String: String], directories: [])
    let executablePath = URL(fileURLWithPath: "/usr/local/bin/copilot")
    let workspaceRoot = URL(fileURLWithPath: "/Users/test/workspace")

    // Create a workspace with 250 files (should trigger multiple notifications)
    let files = (0..<250).map { URL(fileURLWithPath: "/Users/test/workspace/file\($0).swift") }

    let expectWatchedFilesResponse = expectation(description: "watchedFiles response sent")

    let responseData = Atomic<Data?>(nil)
    let notifications = Atomic<[JRPCNotification]>([])

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
          }

        case .response(let response):
          // This is the response to our copilot/watchedFiles request
          if response.id == 1 {
            responseData.set(to: data)
            expectWatchedFilesResponse.fulfill()
          }

        case .notification(let notification):
          if notification.method == "workspace/didChangeWatchedFiles" {
            notifications.mutate { $0.append(notification) }
          }

        default:
          break
        }
      }
    }

    let server = GithubCopilotServer(
      executablePath: executablePath,
      workspace: FrozenWorkspace(url: workspaceRoot, root: workspaceRoot, files: files),
      shellService: shellService,
      fileManager: fileManager,
      jrpcService: mockJRPCService)

    // Wait for initialization to complete
    _ = try await server.initializedTransport.value

    // when
    // Simulate the server sending a copilot/watchedFiles request
    let watchedFilesRequest = """
      {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "copilot/watchedFiles",
        "params": {}
      }
      """
    mockStdioConnection.streamContinuation.yield(watchedFilesRequest.utf8Data)

    // then
    try await fulfillment(of: expectWatchedFilesResponse)

    // Wait for the expected number of notifications to be sent by polling
    let expectNotifications = expectation(description: "All notifications sent")
    Task {
      while notifications.value.count < 2 {
        await Task.yield()
      }
      expectNotifications.fulfill()
    }
    try await fulfillment(of: expectNotifications)

    // Verify the response contains the first 100 files
    let response = try #require(responseData.value)
    let parsedResponse = try JSONDecoder().decode(JRPCResponse.self, from: response)
    #expect(parsedResponse.id == 1)
    #expect(parsedResponse.error == nil)

    if
      case .object(let resultObj) = parsedResponse.result,
      case .array(let changes) = resultObj["changes"]
    {
      #expect(changes.count == 100)
    }

    // Verify we got 2 additional notifications (150 additional files = 2 notifications of 100 each)
    #expect(notifications.value.count == 2)

    _ = server
  }

  @Test("unknown request method returns null response")
  func test_unknownRequestMethod() async throws {
    // given
    let mockStdioConnection = MockStdioConnection()
    let mockJRPCService = MockJRPCService(onCreateConnection: { _, _, _, _ in
      mockStdioConnection
    })

    let shellService = MockShellService()
    let fileManager = MockFileManager(files: [:] as [String: String], directories: [])
    let executablePath = URL(fileURLWithPath: "/usr/local/bin/copilot")
    let workspaceRoot = URL(fileURLWithPath: "/Users/test/workspace")

    let expectUnknownResponse = expectation(description: "unknown method response sent")
    let responseData = Atomic<Data?>(nil)

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
          }

        case .response(let response):
          // This is the response to our unknown request
          if response.id == 1 {
            responseData.set(to: data)
            expectUnknownResponse.fulfill()
          }

        default:
          break
        }
      }
    }

    let server = GithubCopilotServer(
      executablePath: executablePath,
      workspace: FrozenWorkspace(url: workspaceRoot, root: workspaceRoot, files: []),
      shellService: shellService,
      fileManager: fileManager,
      jrpcService: mockJRPCService)

    // Wait for initialization to complete
    _ = try await server.initializedTransport.value

    // when
    // Simulate the server sending an unknown request
    let unknownRequest = """
      {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "unknown/method",
        "params": {}
      }
      """
    mockStdioConnection.streamContinuation.yield(unknownRequest.utf8Data)

    // then
    try await fulfillment(of: expectUnknownResponse)

    let response = try #require(responseData.value)
    let parsedResponse = try JSONDecoder().decode(JRPCResponse.self, from: response)
    #expect(parsedResponse.id == 1)
    #expect(parsedResponse.error == nil)
    // Verify result is .null (not nil optional, but the JSON null value)
    if let result = parsedResponse.result {
      #expect(result == .null)
    }

    _ = server
  }

  // MARK: - Document Sync Tests

  @Test("didOpenTextDocument sends correct notification")
  func test_didOpenTextDocument() async throws {
    // given
    let mockStdioConnection = MockStdioConnection()
    let mockJRPCService = MockJRPCService(onCreateConnection: { _, _, _, _ in
      mockStdioConnection
    })

    let shellService = MockShellService()
    let fileManager = MockFileManager(files: [:] as [String: String], directories: [])
    let executablePath = URL(fileURLWithPath: "/usr/local/bin/copilot")
    let workspaceRoot = URL(fileURLWithPath: "/Users/test/workspace")

    let expectDidOpen = expectation(description: "didOpen notification sent")
    let notificationData = Atomic<Data?>(nil)

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
          }

        case .notification(let notification):
          if notification.method == "textDocument/didOpen" {
            notificationData.set(to: data)
            expectDidOpen.fulfill()
          }

        default:
          break
        }
      }
    }

    let server = GithubCopilotServer(
      executablePath: executablePath,
      workspace: FrozenWorkspace(url: workspaceRoot, root: workspaceRoot, files: []),
      shellService: shellService,
      fileManager: fileManager,
      jrpcService: mockJRPCService)

    // Wait for initialization to complete
    _ = try await server.initializedTransport.value

    // when
    try await server.didOpenTextDocument(
      uri: "file:///Users/test/workspace/test.swift",
      languageId: "swift",
      version: 1,
      text: "let x = 1")

    // then
    try await fulfillment(of: expectDidOpen)

    let data = try #require(notificationData.value)
    let parsedNotification = try JSONDecoder().decode(JRPCNotification.self, from: data)
    #expect(parsedNotification.method == "textDocument/didOpen")

    _ = server
  }

  @Test("didChangeTextDocument sends correct notification")
  func test_didChangeTextDocument() async throws {
    // given
    let mockStdioConnection = MockStdioConnection()
    let mockJRPCService = MockJRPCService(onCreateConnection: { _, _, _, _ in
      mockStdioConnection
    })

    let shellService = MockShellService()
    let fileManager = MockFileManager(files: [:] as [String: String], directories: [])
    let executablePath = URL(fileURLWithPath: "/usr/local/bin/copilot")
    let workspaceRoot = URL(fileURLWithPath: "/Users/test/workspace")

    let expectDidChange = expectation(description: "didChange notification sent")
    let notificationData = Atomic<Data?>(nil)

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
          }

        case .notification(let notification):
          if notification.method == "textDocument/didChange" {
            notificationData.set(to: data)
            expectDidChange.fulfill()
          }

        default:
          break
        }
      }
    }

    let server = GithubCopilotServer(
      executablePath: executablePath,
      workspace: FrozenWorkspace(url: workspaceRoot, root: workspaceRoot, files: []),
      shellService: shellService,
      fileManager: fileManager,
      jrpcService: mockJRPCService)

    // Wait for initialization to complete
    _ = try await server.initializedTransport.value

    // when
    try await server.didChangeTextDocument(
      uri: "file:///Users/test/workspace/test.swift",
      version: 2,
      text: "let x = 2")

    // then
    try await fulfillment(of: expectDidChange)

    let data = try #require(notificationData.value)
    let parsedNotification = try JSONDecoder().decode(JRPCNotification.self, from: data)
    #expect(parsedNotification.method == "textDocument/didChange")

    _ = server
  }

  @Test("didSaveTextDocument sends correct notification")
  func test_didSaveTextDocument() async throws {
    // given
    let mockStdioConnection = MockStdioConnection()
    let mockJRPCService = MockJRPCService(onCreateConnection: { _, _, _, _ in
      mockStdioConnection
    })

    let shellService = MockShellService()
    let fileManager = MockFileManager(files: [:] as [String: String], directories: [])
    let executablePath = URL(fileURLWithPath: "/usr/local/bin/copilot")
    let workspaceRoot = URL(fileURLWithPath: "/Users/test/workspace")

    let expectDidSave = expectation(description: "didSave notification sent")
    let notificationData = Atomic<Data?>(nil)

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
          }

        case .notification(let notification):
          if notification.method == "textDocument/didSave" {
            notificationData.set(to: data)
            expectDidSave.fulfill()
          }

        default:
          break
        }
      }
    }

    let server = GithubCopilotServer(
      executablePath: executablePath,
      workspace: FrozenWorkspace(url: workspaceRoot, root: workspaceRoot, files: []),
      shellService: shellService,
      fileManager: fileManager,
      jrpcService: mockJRPCService)

    // Wait for initialization to complete
    _ = try await server.initializedTransport.value

    // when
    try await server.didSaveTextDocument(
      uri: "file:///Users/test/workspace/test.swift",
      version: 2,
      text: "let x = 2")

    // then
    try await fulfillment(of: expectDidSave)

    let data = try #require(notificationData.value)
    let parsedNotification = try JSONDecoder().decode(JRPCNotification.self, from: data)
    #expect(parsedNotification.method == "textDocument/didSave")

    _ = server
  }

  @Test("didCloseTextDocument sends correct notification")
  func test_didCloseTextDocument() async throws {
    // given
    let mockStdioConnection = MockStdioConnection()
    let mockJRPCService = MockJRPCService(onCreateConnection: { _, _, _, _ in
      mockStdioConnection
    })

    let shellService = MockShellService()
    let fileManager = MockFileManager(files: [:] as [String: String], directories: [])
    let executablePath = URL(fileURLWithPath: "/usr/local/bin/copilot")
    let workspaceRoot = URL(fileURLWithPath: "/Users/test/workspace")

    let expectDidClose = expectation(description: "didClose notification sent")
    let notificationData = Atomic<Data?>(nil)

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
          }

        case .notification(let notification):
          if notification.method == "textDocument/didClose" {
            notificationData.set(to: data)
            expectDidClose.fulfill()
          }

        default:
          break
        }
      }
    }

    let server = GithubCopilotServer(
      executablePath: executablePath,
      workspace: FrozenWorkspace(url: workspaceRoot, root: workspaceRoot, files: []),
      shellService: shellService,
      fileManager: fileManager,
      jrpcService: mockJRPCService)

    // Wait for initialization to complete
    _ = try await server.initializedTransport.value

    // when
    try await server.didCloseTextDocument(
      uri: "file:///Users/test/workspace/test.swift",
      version: 2)

    // then
    try await fulfillment(of: expectDidClose)

    let data = try #require(notificationData.value)
    let parsedNotification = try JSONDecoder().decode(JRPCNotification.self, from: data)
    #expect(parsedNotification.method == "textDocument/didClose")

    _ = server
  }

  // MARK: - Completion Tests

  @Test("getCompletions sends correct request and handles response")
  func test_getCompletions() async throws {
    // given
    let mockStdioConnection = MockStdioConnection()
    let mockJRPCService = MockJRPCService(onCreateConnection: { _, _, _, _ in
      mockStdioConnection
    })

    let shellService = MockShellService()
    let fileManager = MockFileManager(files: [:] as [String: String], directories: [])
    let executablePath = URL(fileURLWithPath: "/usr/local/bin/copilot")
    let workspaceRoot = URL(fileURLWithPath: "/Users/test/workspace")

    let expectCompletionRequest = expectation(description: "completion request sent")

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
          } else if request.method == "textDocument/inlineCompletion" {
            expectCompletionRequest.fulfill()

            // Respond with completions
            let response = """
              {
                "jsonrpc": "2.0",
                "id": \(request.id),
                "result": {
                  "items": [
                    {
                      "insertText": "func example() { return 42 }",
                      "range": {
                        "start": {"line": 0, "character": 0},
                        "end": {"line": 0, "character": 0}
                      }
                    }
                  ]
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
      workspace: FrozenWorkspace(url: workspaceRoot, root: workspaceRoot, files: []),
      shellService: shellService,
      fileManager: fileManager,
      jrpcService: mockJRPCService)

    // Wait for initialization to complete
    _ = try await server.initializedTransport.value

    // Open the file before requesting completions
    try await server.didOpenTextDocument(
      uri: "file:///Users/test/workspace/test.swift",
      languageId: "swift",
      version: 1,
      text: "")

    // when
    let result = try await server.getCompletions(
      uri: "file:///Users/test/workspace/test.swift",
      version: 1,
      position: Position(line: 0, character: 0),
      tabSize: 2,
      insertSpaces: true)

    // then
    try await fulfillment(of: expectCompletionRequest)
    #expect(result.items.count == 1)
    #expect(result.items[0].insertText == "func example() { return 42 }")

    _ = server
  }

  // MARK: - Installation Tests

  @Test("Service with current version installed starts successfully")
  func test_serviceWithCurrentVersionInstalled() async throws {
    // given

    // Create file manager with current version already installed
    // Note: MockFileManager returns "/mock/applicationSupport" for application support directory
    // and Bundle.main.hostAppBundleId returns "dev.getcmd.command" in tests
    let appSupportDir = "/mock/applicationSupport/dev.getcmd.command"
    let currentVersionPath = "\(appSupportDir)/copilot-language-server-1.396.0"

    let fileManager = MockFileManager(
      files: [
        currentVersionPath: "current executable",
      ] as [String: String],
      directories: ["/mock/applicationSupport", appSupportDir])

    let mockStdioConnection = MockStdioConnection()
    let stdioConnectionStarted = expectation(description: "Stdio connection started")
    let mockJRPCService = MockJRPCService(onCreateConnection: { command, _, _, _ in
      #expect(command == "\"\(currentVersionPath)\" --stdio")
      stdioConnectionStarted.fulfill()
      return mockStdioConnection
    })

    let shellService = MockShellService()

    // Track shell commands
    let shellCommands = Atomic<[String]>([])
    shellService.onRun = { command, _, _, _, _ in
      shellCommands.mutate { $0.append(command) }
      return CommandExecutionResult(exitCode: 0)
    }

    // Mock JRPC responses for server initialization
    let hasSentInitializationRequest = expectation(description: "Has sent initialization request")
    let hasCheckedForStatus = expectation(description: "Has checked for status")

    mockStdioConnection.onSend = { data in
      if let message = try? Self.parseJRPCMessage(data) {
        switch message {
        case .request(let request):
          if request.method == "initialize" {
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
            hasSentInitializationRequest.fulfillAtMostOnce()
          } else if request.method == "checkStatus" {
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
            hasCheckedForStatus.fulfillAtMostOnce()
          }

        default:
          break
        }
      }
    }

    // when
    // Create the service with current version installed
    // The service init checks: if currentVersionInstalled || (!currentVersionInstalled && hasAnyVersionInstalled)
    // In our case: currentVersionInstalled = true
    // So it should start the auth server
    let service = DefaultGithubCopilotService(
      shellService: shellService,
      fileManager: fileManager,
      jrpcService: mockJRPCService)

    // Wait for the async installation/auth server setup to complete
    try await fulfillment(of: [stdioConnectionStarted, hasSentInitializationRequest, hasCheckedForStatus])

    // Verify isLSPServerInstalled is true
    #expect(service.isLSPServerInstalled.currentValue == true)
    // Verify no shell commands were run (no installation needed)
    #expect(shellCommands.value.isEmpty)

    #expect(fileManager.files.map { $0.key.path() }.sorted() == [
      currentVersionPath,
    ])

    _ = service
  }

  @Test("Service detects old versions and validates cleanup logic")
  func test_serviceDetectsOldVersionsAndValidatesCleanup() async throws {
    // given

    // Create file manager with current version already installed
    // Note: MockFileManager returns "/mock/applicationSupport" for application support directory
    // and Bundle.main.hostAppBundleId returns "dev.getcmd.command" in tests
    let appSupportDir = "/mock/applicationSupport/dev.getcmd.command"
    let oldVersionPath = "\(appSupportDir)/copilot-language-server-1.0.0"
    let currentVersionPath = "\(appSupportDir)/copilot-language-server-1.396.0"

    let fileManager = MockFileManager(
      files: [
        oldVersionPath: "current executable",
      ] as [String: String],
      directories: ["/mock/applicationSupport", appSupportDir])

    let mockStdioConnection = MockStdioConnection()
    let stdioConnectionStarted = expectation(description: "Stdio connection started")
    let mockJRPCService = MockJRPCService(onCreateConnection: { command, _, _, _ in
      #expect(command == "\"\(currentVersionPath)\" --stdio")
      stdioConnectionStarted.fulfill()
      return mockStdioConnection
    })

    let shellService = MockShellService()

    // Track shell commands
    let hasCalledInstaller = expectation(description: "Installer script called")
    shellService.onRun = { command, _, _, _, _ in
      #expect(command == "/bin/bash \"/mock/applicationSupport/dev.getcmd.command/install-copilot-language-server.sh\"")
      try fileManager.write(string: "", to: URL(string: currentVersionPath)!, options: .atomic)
      hasCalledInstaller.fulfill()
      return CommandExecutionResult(exitCode: 0)
    }

    // Mock JRPC responses for server initialization
    let hasSentInitializationRequest = expectation(description: "Has sent initialization request")
    let hasCheckedForStatus = expectation(description: "Has checked for status")

    mockStdioConnection.onSend = { data in
      if let message = try? Self.parseJRPCMessage(data) {
        switch message {
        case .request(let request):
          if request.method == "initialize" {
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
            hasSentInitializationRequest.fulfillAtMostOnce()
          } else if request.method == "checkStatus" {
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
            hasCheckedForStatus.fulfillAtMostOnce()
          }

        default:
          break
        }
      }
    }

    // when
    // Create the service with only the old version installed
    // The service init checks: if currentVersionInstalled || (!currentVersionInstalled && hasAnyVersionInstalled)
    // In our case: currentVersionInstalled = false, hasAnyVersionInstalled = true
    // So it should run the installer to install the current version and clean up the old version
    let service = DefaultGithubCopilotService(
      shellService: shellService,
      fileManager: fileManager,
      jrpcService: mockJRPCService)

    // Wait for the async installation/auth server setup to complete
    try await fulfillment(of: [hasCalledInstaller, stdioConnectionStarted, hasSentInitializationRequest, hasCheckedForStatus])

    // Verify isLSPServerInstalled is true
    #expect(service.isLSPServerInstalled.currentValue == true)
    // Verify that the old version file has been removed and the new one added.
    #expect(fileManager.files.map { $0.key.path() }.sorted() == [
      currentVersionPath,
    ])

    _ = service
  }

  // MARK: - Helper Methods

  private static func parseJRPCMessage(_ data: Data) throws -> JRPCMessage? {
    try JSONDecoder().decode(JRPCMessage.self, from: data)
  }
}
