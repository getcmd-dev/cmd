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
      ([
        workspace.deletingLastPathComponent().appendingPathComponent("TestXcodeProjParsing.xcodeproj/project.pbxproj"),
        workspace.deletingLastPathComponent()
          .appendingPathComponent("TestXcodeProjParsing/Assets.xcassets/AccentColor.colorset/Contents.json"),
        workspace.deletingLastPathComponent()
          .appendingPathComponent("TestXcodeProjParsing/Assets.xcassets/AppIcon.appiconset/Contents.json"),
        workspace.deletingLastPathComponent().appendingPathComponent("TestXcodeProjParsing/Assets.xcassets/Contents.json"),
        workspace.deletingLastPathComponent().appendingPathComponent("TestXcodeProjParsing/Config.xcconfig"),
        workspace.deletingLastPathComponent().appendingPathComponent("TestXcodeProjParsing/ContentView.swift"),
        workspace.deletingLastPathComponent().appendingPathComponent("TestXcodeProjParsing/Info.plist"),
        workspace.deletingLastPathComponent()
          .appendingPathComponent("TestXcodeProjParsing/Preview Content/Preview Assets.xcassets/Contents.json"),
        workspace.deletingLastPathComponent().appendingPathComponent("TestXcodeProjParsing/TestXcodeProjParsing.entitlements"),
        workspace.deletingLastPathComponent().appendingPathComponent("TestXcodeProjParsing/TestXcodeProjParsingApp.swift"),
        workspace.deletingLastPathComponent().appendingPathComponent("TestXcodeProjParsingTests.xctest"),
        workspace.deletingLastPathComponent().appendingPathComponent("TestXcodeProjParsingTests/TestXcodeProjParsingTests.swift"),
        workspace.deletingLastPathComponent()
          .appendingPathComponent("TestXcodeProjParsingUITests/TestXcodeProjParsingUITests.swift"),
        workspace.deletingLastPathComponent()
          .appendingPathComponent("TestXcodeProjParsingUITests/TestXcodeProjParsingUITestsLaunchTests.swift"),
      ], .xcodeProject)
    }
    let sut = DefaultFileSuggestionService(
      xcodeObserver: xcodeObserver)

    let workspacePath = URL(fileURLWithPath: "/fake/path/TestXcodeProjParsing.xcodeproj")
    let suggestions = try await sut.suggestFiles(for: "Content", in: workspacePath, top: 5)
    #expect(suggestions.map(\.displayPath) == [
      "TestXcodeProjParsing/Assets.xcassets/AccentColor.colorset/Contents.json",
      "TestXcodeProjParsing/Assets.xcassets/AppIcon.appiconset/Contents.json",
      "TestXcodeProjParsing/Assets.xcassets/Contents.json",
      "TestXcodeProjParsing/Preview Content/Preview Assets.xcassets/Contents.json",
      "TestXcodeProjParsing/ContentView.swift",
    ])
  }

  @Test("caching")
  func test_searchUsesFilesCache() async throws {
    let xcodeObserver = MockXcodeObserver()
    let callCount = Atomic(0)
    xcodeObserver.onListFiles = { workspace in
      #expect(callCount.increment() == 1) // Only one call is expected to resolve files.
      return ([
        workspace.appendingPathComponent("Package.swift"),
        workspace.appendingPathComponent("Sources/TestSPM/TestSPM.swift"),
        workspace.appendingPathComponent("Tests/TestSPMTests/TestSPMTests.swift"),
      ], .directory)
    }
    let sut = DefaultFileSuggestionService(
      xcodeObserver: xcodeObserver)

    let workspacePath = URL(fileURLWithPath: "/fake/path/SPM")
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
    let xcodeObserver = MockXcodeObserver()
    let callCount = Atomic(0)
    let didStartConcurrentRequests = expectation(description: "Did start concurrent requests")
    let didCompleteConcurrentRequests = expectation(description: "Did complete concurrent requests")

    xcodeObserver.onListFiles = { workspace in
      #expect(callCount.increment() == 1) // Only one call is expected to resolve files.
      try await fulfillment(of: didStartConcurrentRequests)
      return ([
        workspace.appendingPathComponent("Package.swift"),
        workspace.appendingPathComponent("Sources/TestSPM/TestSPM.swift"),
        workspace.appendingPathComponent("Tests/TestSPMTests/TestSPMTests.swift"),
      ], .directory)
    }
    let sut = DefaultFileSuggestionService(
      xcodeObserver: xcodeObserver)

    let workspacePath = URL(fileURLWithPath: "/fake/path/SPM")
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

}

extension DefaultFileSuggestionService {
  convenience init() {
    self.init(xcodeObserver: MockXcodeObserver())
  }

}
