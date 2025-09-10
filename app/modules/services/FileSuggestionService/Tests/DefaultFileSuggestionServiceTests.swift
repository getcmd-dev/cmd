// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import Foundation
import FoundationInterfaces
import ShellServiceInterface
import SwiftTesting
import Testing
import XcodeObserverServiceInterface
@testable import FileSuggestionService

// MARK: - ClassForBundle

class ClassForBundle { }

// MARK: - DefaultFileSuggestionServiceTests

struct DefaultFileSuggestionServiceTests {

  @Test("xcodeproject")
  func testReadingXcodeProj() async throws {
    let fileManager = try MockFileManager(copyingFrom: URL(fileURLWithPath: Bundle.module.bundlePath))
    let sut = DefaultFileSuggestionService(
      fileManager: fileManager)

    let workspacePath = path(for: "TestXcodeProjParsing/TestXcodeProjParsing.xcodeproj")
    let suggestions = try await sut.suggestFiles(for: "", in: workspacePath, top: 50)
    #expect(suggestions.map(\.displayPath) == [
      "TestXcodeProjParsing.xcodeproj/project.pbxproj",
      "TestXcodeProjParsing/Assets.xcassets/AccentColor.colorset/Contents.json",
      "TestXcodeProjParsing/Assets.xcassets/AppIcon.appiconset/Contents.json",
      "TestXcodeProjParsing/Assets.xcassets/Contents.json",
      "TestXcodeProjParsing/Config.xcconfig",
      "TestXcodeProjParsing/ContentView.swift",
      "TestXcodeProjParsing/Info.plist",
      "TestXcodeProjParsing/Preview Content/Preview Assets.xcassets/Contents.json",
      "TestXcodeProjParsing/TestXcodeProjParsing.entitlements",
      "TestXcodeProjParsing/TestXcodeProjParsingApp.swift",
      "TestXcodeProjParsingTests.xctest",
      "TestXcodeProjParsingTests/TestXcodeProjParsingTests.swift",
      "TestXcodeProjParsingUITests/TestXcodeProjParsingUITests.swift",
      "TestXcodeProjParsingUITests/TestXcodeProjParsingUITestsLaunchTests.swift",
    ])
  }

  @Test("filtered search")
  func test_filteringSearch() async throws {
    let fileManager = try MockFileManager(copyingFrom: URL(fileURLWithPath: Bundle.module.bundlePath))
    let sut = DefaultFileSuggestionService(
      fileManager: fileManager)

    let workspacePath = path(for: "TestXcodeProjParsing/TestXcodeProjParsing.xcodeproj")
    let suggestions = try await sut.suggestFiles(for: "Content", in: workspacePath, top: 5)
    #expect(suggestions.map(\.displayPath) == [
      "TestXcodeProjParsing/Assets.xcassets/AccentColor.colorset/Contents.json",
      "TestXcodeProjParsing/Assets.xcassets/AppIcon.appiconset/Contents.json",
      "TestXcodeProjParsing/Assets.xcassets/Contents.json",
      "TestXcodeProjParsing/Preview Content/Preview Assets.xcassets/Contents.json",
      "TestXcodeProjParsing/ContentView.swift",
    ])
  }

  @Test("SPM")
  func testSwiftPackage() async throws {
    let fileManager = try MockFileManager(copyingFrom: URL(fileURLWithPath: Bundle.module.bundlePath))
    let shellService = MockShellService()
    shellService.onRun = { command, cwd, _, _, _ in
      #expect(command == "swift package describe --type json")
      #expect(cwd?.hasSuffix("/SPM") == true)
      return CommandExecutionResult(exitCode: 0, stdout: spmPackageDescription)
    }
    let sut = DefaultFileSuggestionService(
      fileManager: fileManager,
      shellService: shellService)

    let workspacePath = path(for: "SPM")
    let suggestions = try await sut.suggestFiles(for: "", in: workspacePath, top: 5)
    #expect(suggestions.map(\.displayPath) == [
      "Package.swift",
      "Sources/TestSPM/TestSPM.swift",
      "Tests/TestSPMTests/TestSPMTests.swift",
    ])
  }

  @Test("directory")
  func testFileSuggestionsFromDirectory() async throws {
    // Note: ideally we would entirely mock the file manager. But the code relies on URL's resourceValues which cannot be mocked
    // (`URLResourceValues` cannot be initialized with specific properties).
    let fileManager = try MockFileManager(copyingFrom: URL(fileURLWithPath: Bundle.module.bundlePath))
    let workspacePath = path(for: "directory")

    let sut = DefaultFileSuggestionService(
      fileManager: fileManager)
    let suggestions = try await sut.suggestFiles(for: "", in: workspacePath, top: 5)
    #expect(suggestions.map(\.displayPath).sorted() == [
      "subdirectory/test.txt",
    ])
  }

  @Test("caching")
  func test_searchUsesFilesCache() async throws {
    let fileManager = try MockFileManager(copyingFrom: URL(fileURLWithPath: Bundle.module.bundlePath))
    let shellService = MockShellService()
    let callCount = Atomic(0)
    shellService.onRun = { _, _, _, _, _ in
      #expect(callCount.increment() == 1) // Only one call is expected to resolve files.
      return CommandExecutionResult(exitCode: 0, stdout: spmPackageDescription)
    }
    let sut = DefaultFileSuggestionService(
      fileManager: fileManager,
      shellService: shellService)

    let workspacePath = path(for: "SPM")
    let suggestions = try await sut.suggestFiles(for: "", in: workspacePath, top: 5)
    #expect(suggestions.map(\.displayPath) == [
      "Package.swift",
      "Sources/TestSPM/TestSPM.swift",
      "Tests/TestSPMTests/TestSPMTests.swift",
    ])
    let newSuggestions = try await sut.suggestFiles(for: "Test", in: workspacePath, top: 5)
    #expect(newSuggestions.map(\.displayPath) == [
      "Tests/TestSPMTests/TestSPMTests.swift",
      "Sources/TestSPM/TestSPM.swift",
    ])
  }

  @MainActor
  @Test("merge in-flight requests")
  func test_searchMergesInFlightRequests() async throws {
    let fileManager = try MockFileManager(copyingFrom: URL(fileURLWithPath: Bundle.module.bundlePath))
    let shellService = MockShellService()
    let callCount = Atomic(0)
    let didStartConcurrentRequests = expectation(description: "Did start concurrent requests")
    let didCompleteConcurrentRequests = expectation(description: "Did complete concurrent requests")

    shellService.onRun = { _, _, _, _, _ in
      #expect(callCount.increment() == 1) // Only one call is expected to resolve files.
      try await fulfillment(of: didStartConcurrentRequests)
      return CommandExecutionResult(exitCode: 0, stdout: spmPackageDescription)
    }
    let sut = DefaultFileSuggestionService(
      fileManager: fileManager,
      shellService: shellService)

    let workspacePath = path(for: "SPM")
    Task {
      async let pendingSuggestions = sut.suggestFiles(for: "", in: workspacePath, top: 5)

      async let pendingNewSuggestions = sut.suggestFiles(for: "Test", in: workspacePath, top: 5)
      didStartConcurrentRequests.fulfill()

      let suggestions = try await pendingSuggestions
      let newSuggestions = try await pendingNewSuggestions
      #expect(suggestions.map(\.displayPath) == [
        "Package.swift",
        "Sources/TestSPM/TestSPM.swift",
        "Tests/TestSPMTests/TestSPMTests.swift",
      ])
      #expect(newSuggestions.map(\.displayPath) == [
        "Tests/TestSPMTests/TestSPMTests.swift",
        "Sources/TestSPM/TestSPM.swift",
      ])
      didCompleteConcurrentRequests.fulfill()
    }
    try await fulfillment(of: didCompleteConcurrentRequests)
  }

  private let spmPackageDescription = """
    Warning: some SPM warning that is not JSON...
    {
      "dependencies" : [

      ],
      "manifest_display_name" : "TestSPM",
      "name" : "TestSPM",
      "platforms" : [

      ],
      "products" : [
        {
          "name" : "TestSPM",
          "targets" : [
            "TestSPM"
          ],
          "type" : {
            "library" : [
              "automatic"
            ]
          }
        }
      ],
      "targets" : [
        {
          "c99name" : "TestSPMTests",
          "module_type" : "SwiftTarget",
          "name" : "TestSPMTests",
          "path" : "Tests/TestSPMTests",
          "sources" : [
            "TestSPMTests.swift"
          ],
          "target_dependencies" : [
            "TestSPM"
          ],
          "type" : "test"
        },
        {
          "c99name" : "TestSPM",
          "module_type" : "SwiftTarget",
          "name" : "TestSPM",
          "path" : "Sources/TestSPM",
          "product_memberships" : [
            "TestSPM"
          ],
          "sources" : [
            "TestSPM.swift"
          ],
          "type" : "library"
        }
      ],
      "tools_version" : "6.0"
    }
    """

  private func path(for resource: String) -> URL {
    let bundlePath = URL(fileURLWithPath: Bundle.module.bundlePath)

    if FileManager.default.fileExists(atPath: bundlePath.appendingPathComponent("Contents/Resources/resources/").path) {
      // When running from Xcode, the resources are in the Contents/Resources/Resources/ directory
      return bundlePath.appendingPathComponent("Contents/Resources/resources").appendingPathComponent(resource)
    } else {
      // When running from SPM (CLI), the resources are in the Resources/ directory
      return bundlePath.appendingPathComponent("resources").appendingPathComponent(resource)
    }
  }

}

extension DefaultFileSuggestionService {
  convenience init(
    fileManager: MockFileManager = MockFileManager(),
    shellService: MockShellService = MockShellService())
  {
    self.init(
      fileManager: fileManager as FileManagerI,
      shellService: shellService)
  }

}

extension MockFileManager {
  convenience init(copyingFrom path: URL) throws {
    var files: [String: String] = [:]
    var directories: [String] = []

    if
      let enumerator = FileManager.default.enumerator(
        at: path,
        includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey])
    {
      for case let fileURL as URL in enumerator {
        do {
          let fileAttributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
          if fileAttributes.isRegularFile == true {
            files[fileURL.path] = try FileManager.default.read(contentsOf: fileURL, encoding: .utf8)
          } else if fileAttributes.isDirectory == true {
            directories.append(fileURL.path)
          } else {
            print("Unknown file type: \(fileURL)")
          }
        } catch { }
      }
    }

    self.init(files: files, directories: directories)
  }
}
