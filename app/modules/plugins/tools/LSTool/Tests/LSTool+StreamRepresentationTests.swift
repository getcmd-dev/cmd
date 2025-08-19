// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Dependencies
import Foundation
import SwiftTesting
import Testing
@testable import LSTool
extension LSToolTests {
  struct StreamRepresentationTests {
    @MainActor
    @Test("streamRepresentation returns nil when status is not completed")
    func test_streamRepresentationNilWhenNotCompleted() {
      let (status, _) = LSTool.Use.Status.makeStream(initial: .running)

      let viewModel = ToolUseViewModel(
        status: status,
        directoryPath: URL(filePath: "/test/directory"),
        projectRoot: URL(filePath: "/test"))

      #expect(viewModel.streamRepresentation == nil)
    }

    @MainActor
    @Test("streamRepresentation shows successful listing with multiple files")
    func test_streamRepresentationSuccessMultipleFiles() {
      // given
      let output = LSTool.Use.Output(
        files: [
          .init(path: "/test/directory/file1.swift", attr: "-rw-r--r--", size: "1.2KB"),
          .init(path: "/test/directory/file2.txt", attr: "-rw-r--r--", size: "500B"),
          .init(path: "/test/directory/subdir", attr: "drwxr-xr-x", size: nil),
          .init(path: "/test/directory/image.png", attr: "-rw-r--r--", size: "45KB"),
        ],
        hasMore: false)
      let (status, _) = LSTool.Use.Status.makeStream(initial: .completed(.success(output)))

      let viewModel = ToolUseViewModel(
        status: status,
        directoryPath: URL(filePath: "/test/directory"),
        projectRoot: URL(filePath: "/test"))

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ List(directory)
          ⎿ Listed 4 paths


        """)
    }

    @MainActor
    @Test("streamRepresentation shows successful listing with single file")
    func test_streamRepresentationSuccessSingleFile() {
      // given
      let output = LSTool.Use.Output(
        files: [
          .init(path: "/test/directory/single.swift", attr: "-rw-r--r--", size: "2.1KB"),
        ],
        hasMore: false)
      let (status, _) = LSTool.Use.Status.makeStream(initial: .completed(.success(output)))

      let viewModel = ToolUseViewModel(
        status: status,
        directoryPath: URL(filePath: "/test/directory"),
        projectRoot: URL(filePath: "/test"))

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ List(directory)
          ⎿ Listed 1 paths


        """)
    }

    @MainActor
    @Test("streamRepresentation shows successful listing with no files")
    func test_streamRepresentationSuccessNoFiles() {
      // given
      let output = LSTool.Use.Output(files: [], hasMore: false)
      let (status, _) = LSTool.Use.Status.makeStream(initial: .completed(.success(output)))

      let viewModel = ToolUseViewModel(
        status: status,
        directoryPath: URL(filePath: "/test/empty"),
        projectRoot: URL(filePath: "/test"))

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ List(empty)
          ⎿ Listed 0 paths


        """)
    }

    @MainActor
    @Test("streamRepresentation shows failure with error")
    func test_streamRepresentationFailure() {
      // given
      let error = AppError("Directory not found")
      let (status, _) = LSTool.Use.Status.makeStream(initial: .completed(.failure(error)))

      let viewModel = ToolUseViewModel(
        status: status,
        directoryPath: URL(filePath: "/test/nonexistent"),
        projectRoot: URL(filePath: "/test"))

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ List(nonexistent)
          ⎿ Failed: Directory not found


        """)
    }

    @MainActor
    @Test("streamRepresentation handles permission denied error")
    func test_streamRepresentationPermissionError() {
      // given
      let error = AppError("Permission denied")
      let (status, _) = LSTool.Use.Status.makeStream(initial: .completed(.failure(error)))

      let viewModel = ToolUseViewModel(
        status: status,
        directoryPath: URL(filePath: "/restricted/directory"),
        projectRoot: URL(filePath: "/"))

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ List(restricted/directory)
          ⎿ Failed: Permission denied


        """)
    }

    @MainActor
    @Test("streamRepresentation handles absolute paths without project root")
    func test_streamRepresentationAbsolutePath() {
      // given
      let output = LSTool.Use.Output(
        files: [
          .init(path: "/usr/bin/swift", attr: "-rwxr-xr-x", size: "12MB"),
        ],
        hasMore: false)
      let (status, _) = LSTool.Use.Status.makeStream(initial: .completed(.success(output)))

      let viewModel = ToolUseViewModel(
        status: status,
        directoryPath: URL(filePath: "/usr/bin"),
        projectRoot: nil)

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ List(/usr/bin)
          ⎿ Listed 1 paths


        """)
    }

    @MainActor
    @Test("streamRepresentation handles large directory listing")
    func test_streamRepresentationLargeDirectory() {
      // given
      let files = (1...50).map { i in
        LSTool.Use.Output.File(path: "/test/large/file\(i).txt", attr: "-rw-r--r--", size: "\(i)KB")
      }
      let output = LSTool.Use.Output(files: files, hasMore: false)
      let (status, _) = LSTool.Use.Status.makeStream(initial: .completed(.success(output)))

      let viewModel = ToolUseViewModel(
        status: status,
        directoryPath: URL(filePath: "/test/large"),
        projectRoot: URL(filePath: "/test"))

      // then
      #expect(viewModel.streamRepresentation == """
        ⏺ List(large)
          ⎿ Listed 50 paths


        """)
    }
  }
}
