// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import Foundation
import FoundationInterfaces
import LLMServiceInterface
import SwiftTesting
import Testing
@testable import ReadFileTool

struct ReadFileToolTests {
  @Test
  func completesWithTheExpectedOutcome() async throws {
    let llmService = MockLLMService()
    llmService.onResolve = { path in
      URL(filePath: "/path/to/root").appending(path: path)
    }
    let fileManager = MockFileManager(files: ["/path/to/root/path/to/file.txt": "Hello, world!"])

    let toolUse = withDependencies {
      $0.fileManager = fileManager
      $0.llmService = llmService
    } operation: {
      let toolUse = ReadFileTool().use(
        toolUseId: "123",
        input: .init(path: "path/to/file.txt", lineRange: nil),
        context: .init(project: nil, projectRoot: URL(filePath: "/path/to/root")))
      toolUse.startExecuting()
      return toolUse
    }
    let result = try await toolUse.output
    #expect(result.content == "Hello, world!")
  }

  @Test
  func completesWithAFailureWhenSomethingWentWrong() async throws {
    let llmService = MockLLMService()
    llmService.onResolve = { path in
      URL(filePath: "/path/to/root").appending(path: path)
    }
    let fileManager = MockFileManager(files: [:])

    let toolUse = withDependencies {
      $0.fileManager = fileManager
      $0.llmService = llmService
    } operation: {
      let toolUse = ReadFileTool().use(
        toolUseId: "123",
        input: .init(path: "path/to/file.txt", lineRange: nil),
        context: .init(project: nil, projectRoot: URL(filePath: "/path/to/root")))
      toolUse.startExecuting()
      return toolUse
    }
    await #expect(throws: NSError.self, performing: {
      try await toolUse.output
    })
  }
}
