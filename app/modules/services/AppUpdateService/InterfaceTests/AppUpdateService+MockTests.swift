// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftTesting
import Testing

@testable import AppUpdateServiceInterface

struct MockAppUpdateServiceTests {
  @Test
  func test_usesInitialValues() async throws {
    let updateInfo = AppUpdateInfo(version: "1.0.0", fileURL: nil, releaseNotesURL: nil)
    let sut = MockAppUpdateService(hasUpdateAvailable: .updateAvailable(info: updateInfo))

    if case .updateAvailable(let info) = sut.hasUpdateAvailable.currentValue {
      #expect(info?.version == "1.0.0")
    } else {
      Issue.record("Expected updateAvailable")
    }
  }

  @Test
  func test_defaultInitialValue() async throws {
    let sut = MockAppUpdateService()
    #expect(sut.hasUpdateAvailable.currentValue == .noUpdateAvailable)
  }

  @Test
  func test_updateSubscriberWithNewValues() async throws {
    let sut = MockAppUpdateService(hasUpdateAvailable: .noUpdateAvailable)

    let exp = expectation(description: "Update becomes available")
    let cancellable = sut.hasUpdateAvailable.sink { result in
      if case .updateAvailable = result {
        exp.fulfill()
      }
    }
    #expect(exp.isFulfilled == false)

    let updateInfo = AppUpdateInfo(version: "2.0.0", fileURL: nil, releaseNotesURL: nil)
    sut.setUpdateAvailable(.updateAvailable(info: updateInfo))
    try await fulfillment(of: exp)

    _ = cancellable
  }

  @Test
  func test_relaunchCallsCallback() async throws {
    let sut = MockAppUpdateService()
    let exp = expectation(description: "Relaunch called")

    sut.onRelaunch = {
      exp.fulfill()
    }

    sut.relaunch()
    try await fulfillment(of: exp)
  }

  @Test
  func test_stopCheckingForUpdatesCallsCallback() async throws {
    let sut = MockAppUpdateService()
    let exp = expectation(description: "Stop checking called")

    sut.onStopCheckingForUpdates = {
      exp.fulfill()
    }

    sut.stopCheckingForUpdates()
    try await fulfillment(of: exp)
  }

  @Test
  func test_checkForUpdatesContinuouslyCallsCallback() async throws {
    let sut = MockAppUpdateService()
    let exp = expectation(description: "Check continuously called")

    sut.onCheckForUpdatesContinuously = {
      exp.fulfill()
    }

    sut.checkForUpdatesContinously()
    try await fulfillment(of: exp)
  }

  @Test
  func test_ignoreUpdate_calls_onIgnoreUpdate() async throws {
    let sut = MockAppUpdateService()
    let exp = expectation(description: "Ignore update called")
    let updateInfo = AppUpdateInfo(version: "1.5.0", fileURL: nil, releaseNotesURL: nil)

    sut.onIgnoreUpdate = { version in
      #expect(version?.version == "1.5.0")
      exp.fulfill()
    }

    sut.ignore(update: updateInfo)
    try await fulfillment(of: exp)
  }

  @Test
  func test_ignoreUpdateWithNilVersion() async throws {
    let sut = MockAppUpdateService()
    let exp = expectation(description: "Ignore update called with nil")

    sut.onIgnoreUpdate = { version in
      #expect(version == nil)
      exp.fulfill()
    }

    sut.ignore(update: nil)
    try await fulfillment(of: exp)
  }
}
