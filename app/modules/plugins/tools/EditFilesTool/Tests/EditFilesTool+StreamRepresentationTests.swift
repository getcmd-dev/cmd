// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation
import Testing
@testable import EditFilesTool

extension EditFileToolTests {
  struct StreamRepresentationTests {

    @MainActor
    @Test("streamRepresentation returns nil when status is not completed")
    func test_streamRepresentationNilWhenNotCompleted() async throws {
      let (status, _) = EditFilesTool.Use.Status.makeStream(initial: .running)

      let viewModel = EditFilesToolUseViewModel(
        status: status,
        input: [],
        isInputComplete: true,
        setResult: { _ in })

      #expect(viewModel.streamRepresentation == nil)
    }

    @MainActor
    @Test("streamRepresentation shows applied file changes with relative paths")
    func test_streamRepresentationWithAppliedChanges() async throws {
      let (status, _) = EditFilesTool.Use.Status.makeStream(initial: .completed(.success("Edit successfully applied")))
      let projectRoot = URL(filePath: "/project")

      let viewModel = EditFilesToolUseViewModel(
        status: status,
        input: [],
        isInputComplete: true,
        setResult: { _ in },
        projectRoot: projectRoot)

      // Set up tool use result with applied changes
      viewModel.toolUseResult = EditFilesTool.Use.FormattedOutput(fileChanges: [
        .init(path: "/project/src/file1.swift", isNewFile: false, changeCount: 2, status: .applied),
        .init(path: "/project/docs/readme.md", isNewFile: true, changeCount: 1, status: .applied),
      ])

      let representation = viewModel.streamRepresentation
      #expect(representation == """
        ⏺ Update(src/file1.swift)
          ⎿ Updated

        ⏺ Write(docs/readme.md)
          ⎿ Updated


        """)
    }

    @MainActor
    @Test("streamRepresentation shows error file changes")
    func test_streamRepresentationWithErrorChanges() async throws {
      let (status, _) = EditFilesTool.Use.Status.makeStream(initial: .completed(.success("Edit successfully applied")))

      let viewModel = EditFilesToolUseViewModel(
        status: status,
        input: [],
        isInputComplete: true,
        setResult: { _ in })

      // Set up tool use result with error changes
      viewModel.toolUseResult = EditFilesTool.Use.FormattedOutput(fileChanges: [
        .init(path: "/test/file1.swift", isNewFile: false, changeCount: 1, status: .error(AppError("File locked"))),
      ])

      let representation = viewModel.streamRepresentation
      #expect(representation == """
        ⏺ Update(/test/file1.swift)
          ⎿ Error editing file


        """)
    }

    @MainActor
    @Test("streamRepresentation shows absolute paths when no projectRoot")
    func test_streamRepresentationWithAbsolutePaths() async throws {
      let (status, _) = EditFilesTool.Use.Status.makeStream(initial: .completed(.success("Edit successfully applied")))

      let viewModel = EditFilesToolUseViewModel(
        status: status,
        input: [],
        isInputComplete: true,
        setResult: { _ in },
        projectRoot: nil)

      // Set up tool use result with applied changes
      viewModel.toolUseResult = EditFilesTool.Use.FormattedOutput(fileChanges: [
        .init(path: "/absolute/path/file.swift", isNewFile: false, changeCount: 1, status: .applied),
      ])

      let representation = viewModel.streamRepresentation
      #expect(representation == """
        ⏺ Update(/absolute/path/file.swift)
          ⎿ Updated


        """)
    }

    @MainActor
    @Test("streamRepresentation ignores pending status changes")
    func test_streamRepresentationIgnoresPendingChanges() async throws {
      let (status, _) = EditFilesTool.Use.Status.makeStream(initial: .completed(.success("Edit successfully applied")))

      let viewModel = EditFilesToolUseViewModel(
        status: status,
        input: [],
        isInputComplete: true,
        setResult: { _ in })

      // Set up tool use result with pending changes (should be ignored)
      viewModel.toolUseResult = EditFilesTool.Use.FormattedOutput(fileChanges: [
        .init(path: "/test/file1.swift", isNewFile: false, changeCount: 1, status: .pending),
        .init(path: "/test/file2.swift", isNewFile: false, changeCount: 1, status: .applied),
      ])

      let representation = viewModel.streamRepresentation
      #expect(representation == """
        ⏺ Update(/test/file2.swift)
          ⎿ Updated


        """)
    }
  }
}
