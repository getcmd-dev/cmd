// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppEventServiceInterface
import AppFoundation
import Dependencies
import ExtensionEventsInterface
import FileDiffFoundation
import Foundation
import FoundationInterfaces
import SettingsServiceInterface
import SharedValuesFoundation
import ShellServiceInterface
import SwiftTesting
import Testing
import XcodeControllerServiceInterface
import XcodeObserverServiceInterface
@testable import XcodeControllerService

// MARK: - DefaultXcodeControllerTests

struct DefaultXcodeControllerTests {

  @Test("File edit mode setting is respected - Xcode Extension mode")
  func testFileEditModeXcodeExtension() async throws {
    let testFile = URL(filePath: "test_file.swift")
    let fileContent = "let x = 1"
    let newContent = "let x = 2"

    let xcodeExtensionTriggered = expectation(description: "Xcode extension has been triggered")

    let mockFileManager = MockFileManager(files: [testFile: fileContent], directories: [])

    let appEventHandlerRegistry = MockAppEventHandlerRegistry()

    let controller = DefaultXcodeController(
      appEventHandlerRegistry: appEventHandlerRegistry,
      settingsService: MockSettingsService(Settings(
        pointReleaseXcodeExtensionToDebugApp: false,
        fileEditMode: .xcodeExtension)),
      fileManager: mockFileManager,
      startApplyingFileChangeWithXcodeExtension: {
        xcodeExtensionTriggered.fulfill()
      })

    let fileChange = FileChange(
      filePath: testFile,
      oldContent: fileContent,
      suggestedNewContent: newContent,
      selectedChange: [],
      id: "test")

    async let hasApplied: () = controller.apply(fileChange: fileChange)

    // Verify that the extension was triggered
    try await fulfillment(of: xcodeExtensionTriggered)

    _ = await appEventHandlerRegistry.handle(event: ExecuteExtensionRequestEvent(
      command: ExtensionCommandKeys.getFileChangeToApply,
      id: "123",
      data: Data()) { _ in })

    _ = try await appEventHandlerRegistry.handle(event: ExecuteExtensionRequestEvent(
      command: ExtensionCommandKeys.confirmFileChangeApplied,
      id: "123",
      data: JSONEncoder().encode(ExtensionRequest<FileChangeConfirmation>(
        command: ExtensionCommandKeys.confirmFileChangeApplied,
        input: .init(id: "123", error: nil)))) { _ in })

    try await hasApplied

    // Verify that the file system was not otherwise modified
    let newFileContent = try mockFileManager.read(contentsOf: testFile)
    assert(newFileContent == fileContent)
  }

  @Test("File edit mode setting is respected - Direct I/O mode")
  func testFileEditModeDirectIO() async throws {
    let testFile = URL(filePath: "test_file.swift")
    let fileContent = "let x = 1"
    let newContent = "let x = 2"

    let mockFileManager = MockFileManager(files: [
      testFile.path: fileContent,
    ])

    let controller = DefaultXcodeController(
      settingsService: MockSettingsService(Settings(
        pointReleaseXcodeExtensionToDebugApp: false,
        fileEditMode: .directIO)),
      fileManager: mockFileManager,
      startApplyingFileChangeWithXcodeExtension: {
        Issue.record("Xcode extension should not have been triggered")
      })

    let fileChange = FileChange(
      filePath: testFile,
      oldContent: fileContent,
      suggestedNewContent: newContent,
      selectedChange: [],
      id: "test")

    try await controller.apply(fileChange: fileChange)

    // Verify that the file system has been modified on disk
    let newFileContent = try mockFileManager.read(contentsOf: testFile)
    assert(newFileContent == newContent)
  }

}

extension DefaultXcodeController {
  convenience init(
    appEventHandlerRegistry: MockAppEventHandlerRegistry = MockAppEventHandlerRegistry(),
    shellService: MockShellService = MockShellService(),
    xcodeObserver: MockXcodeObserver = MockXcodeObserver(.unknown),
    settingsService: MockSettingsService = MockSettingsService(Settings(pointReleaseXcodeExtensionToDebugApp: false)),
    fileManager: MockFileManager = MockFileManager(),
    timeout: TimeInterval = 10,
    startApplyingFileChangeWithXcodeExtension: @escaping @Sendable () async throws -> Void = { })
  {
    self.init(
      appEventHandlerRegistry: appEventHandlerRegistry,
      shellService: shellService,
      xcodeObserver: xcodeObserver,
      settingsService: settingsService,
      fileManager: fileManager,
      timeout: timeout,
      canUseAppleScript: false,
      startApplyingFileChangeWithXcodeExtension: startApplyingFileChangeWithXcodeExtension)
  }
}
