// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import CodePreview
import Combine
import ConcurrencyFoundation
import Dependencies
import FileDiffFoundation
import Foundation
import FoundationInterfaces
import JSONFoundation
import SwiftTesting
import Testing
import ToolFoundation
import XcodeControllerServiceInterface
import XcodeObserverServiceInterface
@testable import EditFilesTool

// MARK: - ToolUseViewModelTests

struct ToolUseViewModelTests {
  let testFile = URL(filePath: "/test/example.swift")

  @MainActor
  @Test("Initializes with tool input and creates file diff models")
  func test_initialization() async throws {
    let input = EditFilesTool.Use.Input(files: [
      EditFilesTool.Use.Input.FileChange(
        path: testFile.path,
        isNewFile: nil,
        changes: [
          .init(search: "Hello", replace: "Hi"),
        ]),
    ])

    let (status, _) = EditFilesTool.Use.Status.makeStream(initial: .notStarted)
    let mockFileManager = MockFileManager(files: [testFile.path: "Hello World"])
    let mockXcodeObserver = MockXcodeObserver(fileManager: mockFileManager)

    let viewModel = withDependencies {
      $0.xcodeObserver = mockXcodeObserver
    } operation: {
      ToolUseViewModel(
        status: status,
        input: input.withPathsResolved(from: nil),
        isInputComplete: true,
        setResult: { _ in })
    }

    #expect(viewModel.isInputComplete == true)
    #expect(viewModel.input.count == 1)
    #expect(viewModel.changes.count == 1)
    #expect(viewModel.changes.first?.path.path == testFile.path)
  }

  @MainActor
  @Test("Handles streaming input updates correctly")
  func test_streamingInputUpdates() async throws {
    let initialInput = EditFilesTool.Use.Input(files: [
      EditFilesTool.Use.Input.FileChange(
        path: testFile.path,
        isNewFile: nil,
        changes: [
          .init(search: "Hello", replace: "Hi"),
        ]),
    ])

    let (status, _) = EditFilesTool.Use.Status.makeStream(initial: .notStarted)
    let mockFileManager = MockFileManager(files: [testFile.path: "Hello World Test"])
    let mockXcodeObserver = MockXcodeObserver(fileManager: mockFileManager)

    let viewModel = withDependencies {
      $0.xcodeObserver = mockXcodeObserver
    } operation: {
      ToolUseViewModel(
        status: status,
        input: initialInput.withPathsResolved(from: nil),
        isInputComplete: false,
        setResult: { _ in })
    }

    #expect(viewModel.isInputComplete == false)
    #expect(viewModel.changes.count == 1)

    // Simulate streaming input with additional changes
    let updatedInput = EditFilesTool.Use.Input(files: [
      .init(
        path: testFile.path,
        isNewFile: nil,
        changes: [
          .init(search: "Hello", replace: "Hi"),
          .init(search: "World", replace: "Universe"),
          .init(search: "Test", replace: "Example"),
        ]),
    ])

    viewModel.input = updatedInput.withPathsResolved(from: nil)
    viewModel.isInputComplete = true

    #expect(viewModel.isInputComplete == true)
    #expect(viewModel.changes.count == 1)

    let targetContent = await viewModel.changes.first?.change.targetContent
    #expect(targetContent == "Hi Universe Example")
  }

  @MainActor
  @Test("Processes multiple files in streaming input")
  func test_multipleFilesStreamingInput() async throws {
    let file1Path = URL(filePath: "/test/file1.swift")
    let file2Path = URL(filePath: "/test/file2.swift")

    let initialInput = EditFilesTool.Use.Input(files: [
      EditFilesTool.Use.Input.FileChange(
        path: file1Path.path,
        isNewFile: nil,
        changes: [
          .init(search: "Hello", replace: "Hi"),
        ]),
    ])

    let (status, _) = EditFilesTool.Use.Status.makeStream(initial: .notStarted)
    let mockFileManager = MockFileManager(files: [
      file1Path.path: "Hello World",
      file2Path.path: "Test Code",
    ])
    let mockXcodeObserver = MockXcodeObserver(fileManager: mockFileManager)

    let viewModel = withDependencies {
      $0.xcodeObserver = mockXcodeObserver
    } operation: {
      ToolUseViewModel(
        status: status,
        input: initialInput.withPathsResolved(from: nil),
        isInputComplete: false,
        setResult: { _ in })
    }

    #expect(viewModel.changes.count == 1)

    // Add a second file through streaming
    let updatedInput = EditFilesTool.Use.Input(files: [
      EditFilesTool.Use.Input.FileChange(
        path: file1Path.path,
        isNewFile: nil,
        changes: [
          .init(search: "Hello", replace: "Hi"),
        ]),
      EditFilesTool.Use.Input.FileChange(
        path: file2Path.path,
        isNewFile: nil,
        changes: [
          .init(search: "Test", replace: "Example"),
        ]),
    ])

    withDependencies {
      $0.xcodeObserver = mockXcodeObserver
    } operation: {
      viewModel.input = updatedInput.withPathsResolved(from: nil)
    }

    // Wait for the view model to process the new input
    await waitForUpdate(of: viewModel)

    // Check that the viewModel now has the second file
    #expect(viewModel.changes.map(\.path.path).sorted() == ["/test/file1.swift", "/test/file2.swift"])
  }

  @MainActor
  @Test("Applies changes to single file")
  func test_applySingleFileChanges() async throws {
    let input = EditFilesTool.Use.Input(files: [
      EditFilesTool.Use.Input.FileChange(
        path: testFile.path,
        isNewFile: nil,
        changes: [
          .init(search: "Hello", replace: "Hi"),
        ]),
    ])

    let (status, _) = EditFilesTool.Use.Status.makeStream(initial: .notStarted)
    let mockFileManager = MockFileManager(files: [testFile.path: "Hello World"])
    let mockXcodeObserver = MockXcodeObserver(fileManager: mockFileManager)
    let mockXcodeController = MockXcodeController()

    let applyExpectation = expectation(description: "File change applied")
    mockXcodeController.onApplyFileChange = { fileChange in
      #expect(fileChange.filePath.path == testFile.path)
      #expect(fileChange.oldContent == "Hello World")
      #expect(fileChange.suggestedNewContent == "Hi World")
      applyExpectation.fulfill()
    }

    var toolStatusUpdated = false
    let viewModel = withDependencies {
      $0.xcodeObserver = mockXcodeObserver
      $0.xcodeController = mockXcodeController
    } operation: {
      ToolUseViewModel(
        status: status,
        input: input.withPathsResolved(from: nil),
        isInputComplete: true,
        setResult: { status in
          if status.fileChanges.allSatisfy(\.status.isApplied) {
            toolStatusUpdated = true
          }
        })
    }

    // Wait for initialization
    await waitForUpdate(of: viewModel)

    await viewModel.applyChanges(to: testFile)

    try await fulfillment(of: [applyExpectation])

    #expect(toolStatusUpdated == true)
  }

  @MainActor
  @Test("Applies changes to all files")
  func test_applyAllChanges() async throws {
    let file1Path = URL(filePath: "/test/file1.swift")
    let file2Path = URL(filePath: "/test/file2.swift")

    let input = EditFilesTool.Use.Input(files: [
      EditFilesTool.Use.Input.FileChange(
        path: file1Path.path,
        isNewFile: nil,
        changes: [
          .init(search: "Hello", replace: "Hi"),
        ]),
      EditFilesTool.Use.Input.FileChange(
        path: file2Path.path,
        isNewFile: nil,
        changes: [
          .init(search: "Test", replace: "Example"),
        ]),
    ])

    let (status, _) = EditFilesTool.Use.Status.makeStream(initial: .notStarted)
    let mockFileManager = MockFileManager(files: [
      file1Path.path: "Hello World",
      file2Path.path: "Test Code",
    ])
    let mockXcodeObserver = MockXcodeObserver(fileManager: mockFileManager)
    let mockXcodeController = MockXcodeController()

    let file1ApplyExpectation = expectation(description: "File1 change applied")
    let file2ApplyExpectation = expectation(description: "File2 change applied")

    mockXcodeController.onApplyFileChange = { fileChange in
      if fileChange.filePath.path == file1Path.path {
        #expect(fileChange.suggestedNewContent == "Hi World")
        file1ApplyExpectation.fulfill()
      } else if fileChange.filePath.path == file2Path.path {
        #expect(fileChange.suggestedNewContent == "Example Code")
        file2ApplyExpectation.fulfill()
      }
    }

    var toolStatusUpdated = false
    let viewModel = withDependencies {
      $0.xcodeObserver = mockXcodeObserver
      $0.xcodeController = mockXcodeController
    } operation: {
      ToolUseViewModel(
        status: status,
        input: input.withPathsResolved(from: nil),
        isInputComplete: true,
        setResult: { status in
          if status.fileChanges.allSatisfy(\.status.isApplied) {
            toolStatusUpdated = true
          }
        })
    }

    // Wait for initialization
    await waitForUpdate(of: viewModel)

    await viewModel.applyAllChanges()

    try await fulfillment(of: [file1ApplyExpectation, file2ApplyExpectation])

    #expect(toolStatusUpdated == true)
  }

  @MainActor
  @Test("Undoes applied changes correctly")
  func test_undoAppliedChanges() async throws {
    let input = EditFilesTool.Use.Input(files: [
      EditFilesTool.Use.Input.FileChange(
        path: testFile.path,
        isNewFile: nil,
        changes: [
          .init(search: "Hello", replace: "Hi"),
        ]),
    ])

    let (status, _) = EditFilesTool.Use.Status.makeStream(initial: .notStarted)
    let mockFileManager = MockFileManager(files: [testFile.path: "Hello World"])
    let mockXcodeObserver = MockXcodeObserver(fileManager: mockFileManager)
    let mockXcodeController = MockXcodeController()

    let undoExpectation = expectation(description: "Changes undone")
    mockXcodeController.onApplyFileChange = { fileChange in
      // First call should be applying changes, second should be undoing
      if fileChange.suggestedNewContent == "Hello World" {
        undoExpectation.fulfill()
      }
    }

    var toolStatusUpdated = false
    let viewModel = withDependencies {
      $0.xcodeObserver = mockXcodeObserver
      $0.xcodeController = mockXcodeController
    } operation: {
      ToolUseViewModel(
        status: status,
        input: input.withPathsResolved(from: nil),
        isInputComplete: true,
        setResult: { status in
          if status.fileChanges.allSatisfy(\.status.isApplied) {
            toolStatusUpdated = true
          }
        })
    }

    // Wait for initialization
    await waitForUpdate(of: viewModel)

    // First apply changes
    await viewModel.applyChanges(to: testFile)

    // Then undo changes
    await viewModel.undoChangesApplied(to: testFile)

    try await fulfillment(of: [undoExpectation])

    #expect(toolStatusUpdated == true)
  }

  @MainActor
  @Test("Handles streaming input while processing is in progress")
  func test_streamingInputDuringProcessing() async throws {
    let initialInput = EditFilesTool.Use.Input(files: [
      EditFilesTool.Use.Input.FileChange(
        path: testFile.path,
        isNewFile: nil,
        changes: [
          .init(search: "Hello", replace: "Hi"),
        ]),
    ])

    let (status, _) = EditFilesTool.Use.Status.makeStream(initial: .running)
    let mockFileManager = MockFileManager(files: [testFile.path: "Hello World Test"])
    let mockXcodeObserver = MockXcodeObserver(fileManager: mockFileManager)

    let viewModel = withDependencies {
      $0.xcodeObserver = mockXcodeObserver
    } operation: {
      ToolUseViewModel(
        status: status,
        input: initialInput.withPathsResolved(from: nil),
        isInputComplete: false,
        setResult: { _ in })
    }

    #expect(viewModel.isInputComplete == false)

    // Add more input through streaming
    let updatedInput = EditFilesTool.Use.Input(files: [
      EditFilesTool.Use.Input.FileChange(
        path: testFile.path,
        isNewFile: nil,
        changes: [
          .init(search: "Hello", replace: "Hi"),
          .init(search: "Test", replace: "Example"),
        ]),
    ])

    viewModel.input = updatedInput.withPathsResolved(from: nil)
    viewModel.isInputComplete = true

    #expect(viewModel.isInputComplete == true)
    #expect(viewModel.changes.count == 1)
  }

  @MainActor
  @Test("Acknowledges suggestion received correctly")
  func test_acknowledgeSuggestionReceived() async throws {
    let file1Path = URL(filePath: "/test/file1.swift")
    let file2Path = URL(filePath: "/test/file2.swift")

    let input = EditFilesTool.Use.Input(files: [
      EditFilesTool.Use.Input.FileChange(
        path: file1Path.path,
        isNewFile: nil,
        changes: [
          .init(search: "Hello", replace: "Hi"),
        ]),
      EditFilesTool.Use.Input.FileChange(
        path: file2Path.path,
        isNewFile: nil,
        changes: [
          .init(search: "Test", replace: "Example"),
        ]),
    ])

    let (status, _) = EditFilesTool.Use.Status.makeStream(initial: .notStarted)
    let mockFileManager = MockFileManager(files: [
      file1Path.path: "Hello World",
      file2Path.path: "Test Code",
    ])
    let mockXcodeObserver = MockXcodeObserver(fileManager: mockFileManager)

    var toolStatusUpdated = false
    let viewModel = withDependencies {
      $0.xcodeObserver = mockXcodeObserver
    } operation: {
      ToolUseViewModel(
        status: status,
        input: input.withPathsResolved(from: nil),
        isInputComplete: true,
        setResult: { status in
          if status.fileChanges.allSatisfy(\.status.isApplied) {
            toolStatusUpdated = true
          }
        })
    }

    viewModel.acknowledgeSuggestionReceived()

    #expect(toolStatusUpdated == true)
  }

  private func waitForUpdate(of viewModel: ToolUseViewModel) async {
    _ = await viewModel.changes.last?.change.targetContent
  }

}

extension EditFilesTool.Use.FileChangeStatus {
  var isApplied: Bool {
    if case .applied = self {
      return true
    }
    return false
  }
}
