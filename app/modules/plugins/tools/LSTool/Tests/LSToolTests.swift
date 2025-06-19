// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import Foundation
import ServerServiceInterface
import SwiftTesting
import Testing
@testable import LSTool

struct LSToolTests {
  @Test
  func completesWithTheExpectedOutcome() async throws {
    let server = MockServer()
    server.onPostRequest = { path, data, _ in
      #expect(path == "listFiles")
      data.expectToMatch("""
        {
          "path": "/path/to/root/path/to/dir",
          "recursive": false,
          "projectRoot": "/path/to/root"
        }
        """)
      return try JSONEncoder().encode(Schema.ListFilesToolOutput(files: [
        .init(
          path: "path/to/dir/file.txt",
          isFile: true,
          isDirectory: false,
          isSymlink: false,
          byteSize: 1024,
          permissions: "",
          createdAt: "",
          modifiedAt: ""),
      ]))
    }

    let toolUse = withDependencies {
      $0.server = server
    } operation: {
      let toolUse = LSTool().use(
        toolUseId: "123",
        input: .init(path: "./path/to/dir", recursive: false),
        context: .init(project: nil, projectRoot: URL(filePath: "/path/to/root")))
      toolUse.startExecuting()
      return toolUse
    }
    let result = try await toolUse.output
    #expect(toolUse.directoryPath.path() == "/path/to/root/path/to/dir")
    #expect(result.hasMore == false)
    #expect(result.files.count == 1)
    // The path should be resolved to the absolute path
    #expect(result.files[0].path == "/path/to/root/path/to/dir/file.txt")
  }

  @Test
  func completesWithAFailureWhenSomethingWentWrong() async throws {
    let server = MockServer()
    server.onPostRequest = { _, _, _ in
      throw APIError("unavailable")
    }

    let toolUse = withDependencies {
      $0.server = server
    } operation: {
      let toolUse = LSTool().use(
        toolUseId: "123",
        input: .init(path: "./path/to/dir", recursive: false),
        context: .init(project: nil, projectRoot: URL(filePath: "/path/to/root")))
      toolUse.startExecuting()
      return toolUse
    }
    await #expect(throws: APIError.self, performing: {
      try await toolUse.output
    })
  }
}
