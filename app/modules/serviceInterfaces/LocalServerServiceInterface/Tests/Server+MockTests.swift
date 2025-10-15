// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ConcurrencyFoundation
import Foundation
import SwiftTesting
import Testing
@testable import LocalServerServiceInterface

struct MockLocalServerTests {

  // MARK: - GET Request Tests

  @Test
  func testGetRequestSuccess() async throws {
    let server = MockLocalServer()
    let expectedData = "Hello World".utf8Data
    let receivedData = Atomic<Data?>(nil)

    server.onGetRequest = { path, onReceiveJSONData in
      #expect(path == "/test")
      onReceiveJSONData?(expectedData)
      return Data()
    }

    _ = try await server.getRequest(path: "/test", configure: { _ in }, onReceiveJSONData: { data in
      receivedData.mutate { $0 = data }
    }, idleTimeout: 60)

    #expect(receivedData.value == expectedData)
  }

  @Test
  func testGetRequestFailure() async throws {
    let server = MockLocalServer()

    // Default behavior should throw badServerResponse
    do {
      _ = try await server.getRequest(path: "/test", configure: { _ in }, onReceiveJSONData: nil, idleTimeout: 60)
      Issue.record("Expected error to be thrown")
    } catch let error as URLError {
      #expect(error.code == .badServerResponse)
    }
  }

  @Test
  func testGetRequestCancellation() async throws {
    let server = MockLocalServer()
    let expectation = expectation(description: "Request should be cancelled")

    server.onGetRequest = { _, _ in
      try await Task.sleep(for: .seconds(1))
      return Data()
    }

    let task = Task {
      do {
        _ = try await server.getRequest(path: "/test", configure: { _ in }, onReceiveJSONData: nil, idleTimeout: 60)
        Issue.record("Request should have been cancelled")
      } catch is CancellationError {
        expectation.fulfill()
      }
    }

    // Cancel the task immediately
    task.cancel()
    try await fulfillment(of: expectation)
  }

  // MARK: - POST Request Tests

  @Test
  func testPostRequestSuccess() async throws {
    let server = MockLocalServer()
    let sentData = "Hello LocalServer".utf8Data
    let responseData = "Hello Client".utf8Data
    let receivedData = Atomic<Data?>(nil)

    server.onPostRequest = { path, data, onReceiveJSONData in
      #expect(path == "/test")
      #expect(data == sentData)
      onReceiveJSONData?(responseData)
      return Data()
    }

    _ = try await server.postRequest(path: "/test", data: sentData, configure: { _ in }, onReceiveJSONData: { data in
      receivedData.mutate { $0 = data }
    }, idleTimeout: 60)

    #expect(receivedData.value == responseData)
  }

  @Test
  func testPostRequestFailure() async throws {
    let server = MockLocalServer()
    let testData = "Test".utf8Data

    // Default behavior should throw badServerResponse
    do {
      _ = try await server.postRequest(
        path: "/test",
        data: testData,
        configure: { _ in },
        onReceiveJSONData: nil,
        idleTimeout: 60)
      Issue.record("Expected error to be thrown")
    } catch let error as URLError {
      #expect(error.code == .badServerResponse)
    }
  }

  @Test
  func testPostRequestCancellation() async throws {
    let server = MockLocalServer()
    let testData = "Test".utf8Data
    let expectation = expectation(description: "Request should be cancelled")

    server.onPostRequest = { _, _, _ in
      try await Task.sleep(for: .seconds(1))
      return Data()
    }

    let task = Task {
      do {
        _ = try await server.postRequest(
          path: "/test",
          data: testData,
          configure: { _ in },
          onReceiveJSONData: nil,
          idleTimeout: 60)
        Issue.record("Request should have been cancelled")
      } catch is CancellationError {
        expectation.fulfill()
      }
    }

    // Cancel the task immediately
    task.cancel()
    try await fulfillment(of: expectation)
  }

  @Test
  func testStreamingDataAfterCompletion() async throws {
    let server = MockLocalServer()
    let dataReceived = Atomic<Bool>(false)

    server.onGetRequest = { _, onReceiveJSONData in
      // Try to send data after returning response
      Task {
        try await Task.sleep(for: .milliseconds(100))
        onReceiveJSONData?("Late data".utf8Data)
      }
      return Data()
    }

    _ = try await server.getRequest(path: "/test", configure: { _ in }, onReceiveJSONData: { _ in
      dataReceived.mutate { $0 = true }
    }, idleTimeout: 60)

    // Wait a bit to ensure the delayed data sending attempt happened
    try await Task.sleep(for: .milliseconds(200))
    #expect(dataReceived.value == false, "Should not receive data after request completion")
  }
}
