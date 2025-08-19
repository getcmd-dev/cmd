// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Dependencies
import Foundation
import SwiftTesting
import Testing
@testable import ClaudeCodeTools

struct ClaudeCodeGlobToolStreamRepresentationTests {
  @MainActor
  @Test("streamRepresentation returns nil when status is not completed")
  func test_streamRepresentationNilWhenNotCompleted() {
    let (status, _) = ClaudeCodeGlobTool.Use.Status.makeStream(initial: .running)

    let viewModel = GlobToolUseViewModel(
      status: status,
      input: .init(pattern: "*.swift", path: nil))

    #expect(viewModel.streamRepresentation == nil)
  }

  @MainActor
  @Test("streamRepresentation shows successful glob with multiple files")
  func test_streamRepresentationSuccessMultipleFiles() {
    // given
    let output = ClaudeCodeGlobTool.Use.Output(
      files: [
        "/project/src/main.swift",
        "/project/src/utils.swift",
        "/project/tests/test.swift",
        "/project/views/ContentView.swift",
        "/project/models/User.swift",
      ])
    let (status, _) = ClaudeCodeGlobTool.Use.Status.makeStream(initial: .completed(.success(output)))

    let viewModel = GlobToolUseViewModel(
      status: status,
      input: .init(pattern: "**/*.swift", path: nil))

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ Glob(**/*.swift)
        ⎿ Found 5 files


      """)
  }

  @MainActor
  @Test("streamRepresentation shows successful glob with single file")
  func test_streamRepresentationSuccessSingleFile() {
    // given
    let output = ClaudeCodeGlobTool.Use.Output(
      files: ["/project/src/main.swift"])
    let (status, _) = ClaudeCodeGlobTool.Use.Status.makeStream(initial: .completed(.success(output)))

    let viewModel = GlobToolUseViewModel(
      status: status,
      input: .init(pattern: "main.swift", path: nil))

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ Glob(main.swift)
        ⎿ Found 1 files


      """)
  }

  @MainActor
  @Test("streamRepresentation shows successful glob with no files")
  func test_streamRepresentationSuccessNoFiles() {
    // given
    let output = ClaudeCodeGlobTool.Use.Output(files: [])
    let (status, _) = ClaudeCodeGlobTool.Use.Status.makeStream(initial: .completed(.success(output)))

    let viewModel = GlobToolUseViewModel(
      status: status,
      input: .init(pattern: "*.nonexistent", path: nil))

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ Glob(*.nonexistent)
        ⎿ Found 0 files


      """)
  }

  @MainActor
  @Test("streamRepresentation shows failure with error")
  func test_streamRepresentationFailure() {
    // given
    let error = AppError("Invalid glob pattern")
    let (status, _) = ClaudeCodeGlobTool.Use.Status.makeStream(initial: .completed(.failure(error)))

    let viewModel = GlobToolUseViewModel(
      status: status,
      input: .init(pattern: "invalid[pattern", path: nil))

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ Glob(invalid[pattern)
        ⎿ Failed: Invalid glob pattern


      """)
  }

  @MainActor
  @Test("streamRepresentation handles complex patterns")
  func test_streamRepresentationComplexPatterns() {
    let complexPatterns = [
      "src/**/*.{swift,h,m}",
      "**/Test*.swift",
      "**/{View,Model,Controller}*.swift",
      "!**/Pods/**/*.swift",
    ]

    for pattern in complexPatterns {
      // given
      let output = ClaudeCodeGlobTool.Use.Output(
        files: [
          "/project/src/file1.swift",
          "/project/src/file2.swift",
        ])
      let (status, _) = ClaudeCodeGlobTool.Use.Status.makeStream(initial: .completed(.success(output)))

      let viewModel = GlobToolUseViewModel(
        status: status,
        input: .init(pattern: pattern, path: nil))

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ Glob(\(pattern))
          ⎿ Found 2 files


        """)
    }
  }

  @MainActor
  @Test("streamRepresentation handles directory access error")
  func test_streamRepresentationDirectoryAccessError() {
    // given
    let error = AppError("Permission denied")
    let (status, _) = ClaudeCodeGlobTool.Use.Status.makeStream(initial: .completed(.failure(error)))

    let viewModel = GlobToolUseViewModel(
      status: status,
      input: .init(pattern: "/restricted/directory/*.swift", path: nil))

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ Glob(/restricted/directory/*.swift)
        ⎿ Failed: Permission denied


      """)
  }
}
