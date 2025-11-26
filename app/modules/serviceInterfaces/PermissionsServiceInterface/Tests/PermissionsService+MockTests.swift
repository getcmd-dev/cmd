// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Observation
import SwiftTesting
import Testing

@testable import PermissionsServiceInterface

struct MockPermissionsServiceTests {
  @Test
  func test_usesInitialValues() async throws {
    let sut = MockPermissionsService(grantedPermissions: [.accessibility])
    #expect(sut.status(for: .accessibility).currentValue == .grantedEnabled)
    #expect(sut.status(for: .xcodeExtension).currentValue == .notGranted)
    #expect(sut.status(for: .xcodeAutomation).currentValue == .notGranted)
  }

  @Test
  func test_updateSubscriberWithNewValues() async throws {
    let sut = MockPermissionsService(grantedPermissions: [.accessibility])

    let exp = expectation(description: "Xcode extension permission granted")
    let cancellable = sut.status(for: .xcodeExtension).sink { status in
      if status.isGranted {
        exp.fulfill()
      }
    }
    #expect(exp.isFulfilled == false)
    Task { @MainActor in
      sut.set(permission: .xcodeExtension, status: .grantedEnabled)
    }
    try await fulfillment(of: exp)

    _ = cancellable
  }

  @Test
  func test_xcodeAutomationUsesInitialValues() async throws {
    let sut = MockPermissionsService(grantedPermissions: [.xcodeAutomation])
    #expect(sut.status(for: .xcodeAutomation).currentValue == .grantedEnabled)
    #expect(sut.status(for: .accessibility).currentValue == .notGranted)
  }

  @Test
  func test_xcodeAutomationUpdateSubscriberWithNewValues() async throws {
    let sut = MockPermissionsService(grantedPermissions: [])

    let exp = expectation(description: "Xcode automation permission granted")
    let cancellable = sut.status(for: .xcodeAutomation).sink { status in
      if status.isGranted {
        exp.fulfill()
      }
    }
    #expect(exp.isFulfilled == false)
    Task { @MainActor in
      sut.set(permission: .xcodeAutomation, status: .grantedEnabled)
    }
    try await fulfillment(of: exp)

    _ = cancellable
  }
}
