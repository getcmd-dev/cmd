// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Dependencies
import Foundation
import SwiftTesting
import Testing
@testable import ReadFileTool

extension ReadFileToolTests {
  struct StreamRepresentationTests {
    @MainActor
    @Test("streamRepresentation returns nil when status is not completed")
    func test_streamRepresentationNilWhenNotCompleted() {
      let (status, _) = ReadFileTool.Use.Status.makeStream(initial: .running)

      let viewModel = ToolUseViewModel(
        status: status,
        input: .init(path: "/test/file.swift", lineRange: nil), projectRoot: nil)

      #expect(viewModel.streamRepresentation == nil)
    }

    @MainActor
    @Test("streamRepresentation shows successful read with multiple lines")
    func test_streamRepresentationSuccessMultipleLines() {
      // given
      let content = """
        import Foundation

        class TestClass {
          func testMethod() {
            print("Hello, World!")
          }
        }
        """
      let output = ReadFileTool.Use.Output(
        content: content,
        uri: "/test/file.swift")
      let (status, _) = ReadFileTool.Use.Status.makeStream(initial: .completed(.success(output)))

      let viewModel = ToolUseViewModel(
        status: status,
        input: .init(path: "/test/file.swift", lineRange: nil), projectRoot: nil)

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ Read(/test/file.swift)
          ⎿ Read 7 lines


        """)
    }

    @MainActor
    @Test("streamRepresentation shows successful read with single line")
    func test_streamRepresentationSuccessSingleLine() {
      // given
      let content = "print('Hello, World!')"
      let output = ReadFileTool.Use.Output(
        content: content,
        uri: "/test/simple.py")
      let (status, _) = ReadFileTool.Use.Status.makeStream(initial: .completed(.success(output)))

      let viewModel = ToolUseViewModel(
        status: status,
        input: .init(path: "/test/simple.py", lineRange: nil), projectRoot: nil)

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ Read(/test/simple.py)
          ⎿ Read 1 lines


        """)
    }

    @MainActor
    @Test("streamRepresentation uses relative path when project root is provided")
    func test_streamRepresentationUseRelativePath() {
      // given
      let content = "print('Hello, World!')"
      let output = ReadFileTool.Use.Output(
        content: content,
        uri: "/test/simple.py")
      let (status, _) = ReadFileTool.Use.Status.makeStream(initial: .completed(.success(output)))

      let viewModel = ToolUseViewModel(
        status: status,
        input: .init(path: "/test/simple.py", lineRange: nil), projectRoot: URL(filePath: "/test"))

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ Read(simple.py)
          ⎿ Read 1 lines


        """)
    }

    @MainActor
    @Test("streamRepresentation shows successful read with empty file")
    func test_streamRepresentationSuccessEmptyFile() {
      // given
      let output = ReadFileTool.Use.Output(
        content: "",
        uri: "/test/empty.txt")
      let (status, _) = ReadFileTool.Use.Status.makeStream(initial: .completed(.success(output)))

      let viewModel = ToolUseViewModel(
        status: status,
        input: .init(path: "/test/empty.txt", lineRange: nil), projectRoot: nil)

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ Read(/test/empty.txt)
          ⎿ Read 1 lines


        """)
    }

    @MainActor
    @Test("streamRepresentation shows successful read with line range")
    func test_streamRepresentationSuccessWithRange() {
      // given
      let content = """
        Line 1
        Line 2
        Line 3
        Line 4
        Line 5
        """
      let output = ReadFileTool.Use.Output(
        content: content,
        uri: "/test/range.txt")
      let (status, _) = ReadFileTool.Use.Status.makeStream(initial: .completed(.success(output)))

      let viewModel = ToolUseViewModel(
        status: status,
        input: .init(
          path: "/test/range.txt",
          lineRange: .init(start: 2, end: 4)), projectRoot: nil)

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ Read(/test/range.txt)
          ⎿ Read 5 lines


        """)
    }

    @MainActor
    @Test("streamRepresentation shows failure with error")
    func test_streamRepresentationFailure() {
      // given
      let error = AppError("File not found")
      let (status, _) = ReadFileTool.Use.Status.makeStream(initial: .completed(.failure(error)))

      let viewModel = ToolUseViewModel(
        status: status,
        input: .init(path: "/test/nonexistent.swift", lineRange: nil), projectRoot: nil)

      // then
      #expect(viewModel.streamRepresentation == """
          ⏺ Read(/test/nonexistent.swift)
            ⎿ Failed: File not found


        """)
    }

    @MainActor
    @Test("streamRepresentation handles permission denied error")
    func test_streamRepresentationPermissionError() {
      // given
      let error = AppError("Permission denied")
      let (status, _) = ReadFileTool.Use.Status.makeStream(initial: .completed(.failure(error)))

      let viewModel = ToolUseViewModel(
        status: status,
        input: .init(path: "/root/secret.txt", lineRange: nil), projectRoot: nil)

      // then
      #expect(viewModel.streamRepresentation == """
          ⏺ Read(/root/secret.txt)
            ⎿ Failed: Permission denied


        """)
    }

    @MainActor
    @Test("streamRepresentation handles different file types")
    func test_streamRepresentationDifferentFileTypes() {
      let testCases = [
        ("/test/config.json", "{\n  \"name\": \"test\"\n}"),
        ("/test/README.md", "# Test Project\n\nThis is a test."),
        ("/test/style.css", ".test { color: red; }"),
        ("/test/script.js", "console.log('Hello');"),
      ]

      for (filePath, content) in testCases {
        // given
        let output = ReadFileTool.Use.Output(content: content, uri: filePath)
        let (status, _) = ReadFileTool.Use.Status.makeStream(initial: .completed(.success(output)))

        let viewModel = ToolUseViewModel(
          status: status,
          input: .init(path: filePath, lineRange: nil), projectRoot: nil)

        // then
        let expectedLines = content.split(separator: "\n", omittingEmptySubsequences: false).count
        #expect(viewModel.streamRepresentation == """
          ⏺ Read(\(filePath))
            ⎿ Read \(expectedLines) lines


          """)
      }
    }

    @MainActor
    @Test("streamRepresentation handles binary file error")
    func test_streamRepresentationBinaryFileError() {
      // given
      let error = AppError("Cannot read binary file")
      let (status, _) = ReadFileTool.Use.Status.makeStream(initial: .completed(.failure(error)))

      let viewModel = ToolUseViewModel(
        status: status,
        input: .init(path: "/test/image.png", lineRange: nil), projectRoot: nil)

      // then
      #expect(viewModel.streamRepresentation == """
          ⏺ Read(/test/image.png)
            ⎿ Failed: Cannot read binary file


        """)
    }

    @MainActor
    @Test("streamRepresentation handles large file with newlines")
    func test_streamRepresentationLargeFile() {
      // given
      let lines = (1...100).map { "Line \($0)" }
      let content = lines.joined(separator: "\n")
      let output = ReadFileTool.Use.Output(
        content: content,
        uri: "/test/large.txt")
      let (status, _) = ReadFileTool.Use.Status.makeStream(initial: .completed(.success(output)))

      let viewModel = ToolUseViewModel(
        status: status,
        input: .init(path: "/test/large.txt", lineRange: nil), projectRoot: nil)

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ Read(/test/large.txt)
          ⎿ Read 100 lines


        """)
    }
  }
}
