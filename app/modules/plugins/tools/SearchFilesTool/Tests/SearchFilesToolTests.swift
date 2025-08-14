// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import Foundation
import LocalServerServiceInterface
import SwiftTesting
import Testing
@testable import SearchFilesTool

struct SearchFilesToolTests {
  @Test
  func completesWithTheExpectedOutcome() async throws {
    let server = MockLocalServer()
    server.onPostRequest = { path, data, _ in
      #expect(path == "searchFiles")
      data.expectToMatch("""
        {
          "directoryPath" : "/path/to/root",
          "filePattern" : "*.swift",
          "projectRoot" : "/path/to/root",
          "regex" : "func*"
        }
        """)
      return try JSONEncoder().encode(Schema.SearchFilesToolOutput(
        outputForLLm: "here's some result:...",
        results: [
          .init(path: "somefile.swift", searchResults: [
            .init(line: 1, text: "func foo() {\n", isMatch: true),
          ]),
        ],
        rootPath: "/path/to/root",
        hasMore: false))
    }

    let toolUse = withDependencies {
      $0.localServer = server
    } operation: {
      let toolUse = SearchFilesTool().use(
        toolUseId: "123",
        input: .init(directoryPath: ".", regex: "func*", filePattern: "*.swift"),
        isInputComplete: true,
        context: .init(projectRoot: URL(filePath: "/path/to/root")))
      toolUse.startExecuting()
      return toolUse
    }
    let result = try await toolUse.output
    #expect(result.hasMore == false)
    #expect(result.results.count == 1)
    // The path should be resolved to the absolute path
    #expect(result.results.first?.path == "/path/to/root/somefile.swift")
  }

  @Test
  func completesWithAFailureWhenSomethingWentWrong() async throws {
    let server = MockLocalServer()
    server.onPostRequest = { _, _, _ in
      throw APIError("unavailable")
    }

    let toolUse = withDependencies {
      $0.localServer = server
    } operation: {
      let toolUse = SearchFilesTool().use(
        toolUseId: "123",
        input: .init(directoryPath: ".", regex: "func*", filePattern: "*.swift"),
        isInputComplete: true,
        context: .init(projectRoot: URL(filePath: "/path/to/root")))
      toolUse.startExecuting()
      return toolUse
    }
    await #expect(throws: APIError.self, performing: {
      try await toolUse.output
    })
  }
}
