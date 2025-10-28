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
    let input = ClaudeCodeGlobTool.Use.Input(pattern: "*.swift", path: nil)
    let (status, _) = ClaudeCodeGlobTool.Use.Status.makeStream(initial: .running(input: input))

    let viewModel = GlobToolUseViewModel(
      status: status,
      input: input)

    #expect(viewModel.streamRepresentation == nil)
  }

  @MainActor
  @Test("streamRepresentation shows successful glob with multiple files")
  func test_streamRepresentationSuccessMultipleFiles() {
    // given
    let input = ClaudeCodeGlobTool.Use.Input(pattern: "**/*.swift", path: nil)
    let output = ClaudeCodeGlobTool.Use.Output(
      files: [
        "/project/src/main.swift",
        "/project/src/utils.swift",
        "/project/tests/test.swift",
        "/project/views/ContentView.swift",
        "/project/models/User.swift",
      ])
    let (status, _) = ClaudeCodeGlobTool.Use.Status.makeStream(initial: .completed(input: input, result: .success(output)))

    let viewModel = GlobToolUseViewModel(
      status: status,
      input: input)

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
    let input = ClaudeCodeGlobTool.Use.Input(pattern: "main.swift", path: nil)
    let output = ClaudeCodeGlobTool.Use.Output(
      files: ["/project/src/main.swift"])
    let (status, _) = ClaudeCodeGlobTool.Use.Status.makeStream(initial: .completed(input: input, result: .success(output)))

    let viewModel = GlobToolUseViewModel(
      status: status,
      input: input)

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
    let input = ClaudeCodeGlobTool.Use.Input(pattern: "*.nonexistent", path: nil)
    let output = ClaudeCodeGlobTool.Use.Output(files: [])
    let (status, _) = ClaudeCodeGlobTool.Use.Status.makeStream(initial: .completed(input: input, result: .success(output)))

    let viewModel = GlobToolUseViewModel(
      status: status,
      input: input)

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
    let input = ClaudeCodeGlobTool.Use.Input(pattern: "invalid[pattern", path: nil)
    let error = AppError("Invalid glob pattern")
    let (status, _) = ClaudeCodeGlobTool.Use.Status.makeStream(initial: .completed(input: input, result: .failure(error)))

    let viewModel = GlobToolUseViewModel(
      status: status,
      input: input)

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
      let input = ClaudeCodeGlobTool.Use.Input(pattern: pattern, path: nil)
      let output = ClaudeCodeGlobTool.Use.Output(
        files: [
          "/project/src/file1.swift",
          "/project/src/file2.swift",
        ])
      let (status, _) = ClaudeCodeGlobTool.Use.Status.makeStream(initial: .completed(input: input, result: .success(output)))

      let viewModel = GlobToolUseViewModel(
        status: status,
        input: input)

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
    let input = ClaudeCodeGlobTool.Use.Input(pattern: "/restricted/directory/*.swift", path: nil)
    let error = AppError("Permission denied")
    let (status, _) = ClaudeCodeGlobTool.Use.Status.makeStream(initial: .completed(input: input, result: .failure(error)))

    let viewModel = GlobToolUseViewModel(
      status: status,
      input: input)

    // then
    #expect(viewModel.streamRepresentation == """
      ⏺ Glob(/restricted/directory/*.swift)
        ⎿ Failed: Permission denied


      """)
  }
}
