// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import Foundation
import SwiftTesting
import Testing
import XcodeObserverServiceInterface
@testable import FileSuggestionService

// MARK: - DefaultFileSuggestionServiceTests

struct DefaultFileSuggestionServiceTests {

  @Test("filtered search")
  func test_filteringSearch() async throws {
    let xcodeObserver = MockXcodeObserver()
    xcodeObserver.onListFiles = { workspace in
      // Simulate listing files for xcodeproj
      let rootDir = workspace.deletingLastPathComponent()
      return ListFilesResult(
        files: [
          rootDir.appendingPathComponent("TestXcodeProjParsing.xcodeproj/project.pbxproj"),
          rootDir.appendingPathComponent("TestXcodeProjParsing/Assets.xcassets/AccentColor.colorset/Contents.json"),
          rootDir.appendingPathComponent("TestXcodeProjParsing/Assets.xcassets/AppIcon.appiconset/Contents.json"),
          rootDir.appendingPathComponent("TestXcodeProjParsing/Assets.xcassets/Contents.json"),
          rootDir.appendingPathComponent("TestXcodeProjParsing/Config.xcconfig"),
          rootDir.appendingPathComponent("TestXcodeProjParsing/ContentView.swift"),
          rootDir.appendingPathComponent("TestXcodeProjParsing/Info.plist"),
          rootDir.appendingPathComponent("TestXcodeProjParsing/Preview Content/Preview Assets.xcassets/Contents.json"),
          rootDir.appendingPathComponent("TestXcodeProjParsing/TestXcodeProjParsing.entitlements"),
          rootDir.appendingPathComponent("TestXcodeProjParsing/TestXcodeProjParsingApp.swift"),
          rootDir.appendingPathComponent("TestXcodeProjParsingTests.xctest"),
          rootDir.appendingPathComponent("TestXcodeProjParsingTests/TestXcodeProjParsingTests.swift"),
          rootDir.appendingPathComponent("TestXcodeProjParsingUITests/TestXcodeProjParsingUITests.swift"),
          rootDir.appendingPathComponent("TestXcodeProjParsingUITests/TestXcodeProjParsingUITestsLaunchTests.swift"),
        ],
        workspaceType: .xcodeProject,
        workspaceRoot: rootDir)
    }
    let sut = DefaultFileSuggestionService(
      xcodeObserver: xcodeObserver)

    let workspacePath = URL(fileURLWithPath: "/fake/path/TestXcodeProjParsing.xcodeproj")
    let suggestions = try await sut.suggestFiles(for: "Content", in: workspacePath, top: 10)
    let fileSuggestions = suggestions.filter { !$0.isDirectory }
    #expect(fileSuggestions.prefix(5).map(\.displayPath) == [
      "TestXcodeProjParsing/Assets.xcassets/AccentColor.colorset/Contents.json",
      "TestXcodeProjParsing/Assets.xcassets/AppIcon.appiconset/Contents.json",
      "TestXcodeProjParsing/Assets.xcassets/Contents.json",
      "TestXcodeProjParsing/Preview Content/Preview Assets.xcassets/Contents.json",
      "TestXcodeProjParsing/ContentView.swift",
    ])
    #expect(suggestions.contains { $0.isDirectory })
  }

  @Test("does fuzzy matching")
  func test_fuzzyMatching() async throws {
    let xcodeObserver = MockXcodeObserver()
    let callCount = Atomic(0)
    xcodeObserver.onListFiles = { workspace in
      #expect(callCount.increment() == 1) // Only one call is expected to resolve files.
      return ListFilesResult(
        files: [
          workspace.appendingPathComponent("Package.swift"),
          workspace.appendingPathComponent("Sources/TestSPM/TestSPM.swift"),
          workspace.appendingPathComponent("Tests/TestSPMTests/TestSPMTests.swift"),
        ],
        workspaceType: .directory,
        workspaceRoot: workspace)
    }
    let sut = DefaultFileSuggestionService(
      xcodeObserver: xcodeObserver)

    let workspacePath = URL(fileURLWithPath: "/fake/path/SPM")
    let suggestions = try await sut
      .suggestFiles(for: "tEt", in: workspacePath, top: 10) // Like Test, with different casing and one missing character
    let fileDisplayPaths = suggestions.map(\.displayPath)
    #expect(fileDisplayPaths == [
      "Tests",
      "Tests/TestSPMTests",
      "Sources/TestSPM",
      "Tests/TestSPMTests/TestSPMTests.swift",
      "Sources/TestSPM/TestSPM.swift",
    ])
  }

  @Test("caching")
  func test_searchUsesFilesCache() async throws {
    let xcodeObserver = MockXcodeObserver()
    let callCount = Atomic(0)
    xcodeObserver.onListFiles = { workspace in
      #expect(callCount.increment() == 1) // Only one call is expected to resolve files.
      return ListFilesResult(
        files: [
          workspace.appendingPathComponent("Package.swift"),
          workspace.appendingPathComponent("Sources/TestSPM/TestSPM.swift"),
          workspace.appendingPathComponent("Tests/TestSPMTests/TestSPMTests.swift"),
        ],
        workspaceType: .directory,
        workspaceRoot: workspace)
    }
    let sut = DefaultFileSuggestionService(
      xcodeObserver: xcodeObserver)

    let workspacePath = URL(fileURLWithPath: "/fake/path/SPM")
    let suggestions = try await sut.suggestFiles(for: "", in: workspacePath, top: 10)
    let fileDisplayPaths = suggestions.filter { !$0.isDirectory }.map(\.displayPath)
    #expect(fileDisplayPaths == [
      "Package.swift",
      "Sources/TestSPM/TestSPM.swift",
      "Tests/TestSPMTests/TestSPMTests.swift",
    ])
    #expect(suggestions.contains { $0.isDirectory })
    let newSuggestions = try await sut.suggestFiles(for: "Test", in: workspacePath, top: 10)
    let newFileDisplayPaths = newSuggestions.filter { !$0.isDirectory }.map(\.displayPath)
    #expect(newFileDisplayPaths == [
      "Tests/TestSPMTests/TestSPMTests.swift",
      "Sources/TestSPM/TestSPM.swift",
    ])
  }

  @MainActor
  @Test("merge in-flight requests")
  func test_searchMergesInFlightRequests() async throws {
    let xcodeObserver = MockXcodeObserver()
    let callCount = Atomic(0)
    let didStartConcurrentRequests = expectation(description: "Did start concurrent requests")
    let didCompleteConcurrentRequests = expectation(description: "Did complete concurrent requests")

    xcodeObserver.onListFiles = { workspace in
      #expect(callCount.increment() == 1) // Only one call is expected to resolve files.
      try await fulfillment(of: didStartConcurrentRequests)
      return ListFilesResult(
        files: [
          workspace.appendingPathComponent("Package.swift"),
          workspace.appendingPathComponent("Sources/TestSPM/TestSPM.swift"),
          workspace.appendingPathComponent("Tests/TestSPMTests/TestSPMTests.swift"),
        ],
        workspaceType: .directory,
        workspaceRoot: workspace)
    }
    let sut = DefaultFileSuggestionService(
      xcodeObserver: xcodeObserver)

    let workspacePath = URL(fileURLWithPath: "/fake/path/SPM")
    Task {
      async let pendingSuggestions = sut.suggestFiles(for: "", in: workspacePath, top: 8)

      async let pendingNewSuggestions = sut.suggestFiles(for: "Test", in: workspacePath, top: 8)
      didStartConcurrentRequests.fulfill()

      let suggestions = try await pendingSuggestions
      let newSuggestions = try await pendingNewSuggestions
      #expect(suggestions.filter { !$0.isDirectory }.map(\.displayPath) == [
        "Package.swift",
        "Sources/TestSPM/TestSPM.swift",
        "Tests/TestSPMTests/TestSPMTests.swift",
      ])
      #expect(suggestions.contains { $0.isDirectory })
      #expect(newSuggestions.filter { !$0.isDirectory }.map(\.displayPath) == [
        "Tests/TestSPMTests/TestSPMTests.swift",
        "Sources/TestSPM/TestSPM.swift",
      ])
      didCompleteConcurrentRequests.fulfill()
    }
    try await fulfillment(of: didCompleteConcurrentRequests)
  }

}

extension DefaultFileSuggestionService {
  convenience init() {
    self.init(xcodeObserver: MockXcodeObserver())
  }

}
