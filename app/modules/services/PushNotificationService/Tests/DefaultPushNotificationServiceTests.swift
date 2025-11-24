// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import PermissionsServiceInterface
import PushNotificationServiceInterface
import SwiftTesting
import Testing

@testable import PushNotificationService

// MARK: - DefaultPushNotificationServiceTests

struct DefaultPushNotificationServiceTests {

  @Test
  func test_sendNotification() async throws {
    let sut = MockPushNotificationService()

    let notification = PushNotification(
      title: "Test Title",
      body: "Test Body",
      actions: [PushNotificationAction(title: "Action 1", callback: { })])

    try await sut.send(notification)

    let count = sut.activeNotificationCount().currentValue
    #expect(count == 1)
  }

  @Test
  func test_handleActionCallback() async throws {
    let sut = MockPushNotificationService()
    let callbackExp = expectation(description: "callback executed")

    let action = PushNotificationAction(title: "Action 1", callback: {
      callbackExp.fulfill()
    })

    let notification = PushNotification(title: "Test", body: "Body", actions: [action])
    try await sut.send(notification)
    await sut.handleActionCallback(actionIdentifier: action.identifier)

    try await fulfillment(of: callbackExp)
  }

  @Test
  func test_sendNotificationWithoutActions() async throws {
    let sut = MockPushNotificationService()

    try await sut.send(PushNotification(title: "Test", body: "Body"))

    let count = sut.activeNotificationCount().currentValue
    #expect(count == 1)
  }

  @Test
  func test_activeNotificationCount() async throws {
    let sut = MockPushNotificationService()

    // Initially no notifications
    var count = sut.activeNotificationCount().currentValue
    #expect(count == 0)

    // Add notification
    try await sut.send(PushNotification(title: "Test 1", body: "Body 1"))

    count = sut.activeNotificationCount().currentValue
    #expect(count == 1)
  }

  @Test
  func test_activeNotifications() async throws {
    let sut = MockPushNotificationService()

    let notification1 = PushNotification(title: "Test 1", body: "Body 1")
    let notification2 = PushNotification(title: "Test 2", body: "Body 2")

    try await sut.send(notification1)
    try await sut.send(notification2)

    let notifications = sut.activeNotifications().currentValue
    #expect(notifications.count == 2)
    #expect(notifications[0].title == "Test 1")
    #expect(notifications[1].title == "Test 2")
  }

  @Test
  func test_clearAllNotifications() async throws {
    let sut = MockPushNotificationService()

    try await sut.send(PushNotification(title: "Test 1", body: "Body 1"))
    try await sut.send(PushNotification(title: "Test 2", body: "Body 2"))

    var count = sut.activeNotificationCount().currentValue
    #expect(count == 2)

    await sut.clearAllNotifications()

    count = sut.activeNotificationCount().currentValue
    #expect(count == 0)
  }

  @Test
  func test_clearSpecificNotification() async throws {
    let sut = MockPushNotificationService()

    let notification1 = PushNotification(title: "Test 1", body: "Body 1")
    let notification2 = PushNotification(title: "Test 2", body: "Body 2")

    try await sut.send(notification1)
    try await sut.send(notification2)

    let notifications = sut.activeNotifications().currentValue
    #expect(notifications.count == 2)

    await sut.clear(notification: notification1)

    let remainingCount = sut.activeNotificationCount().currentValue
    #expect(remainingCount == 1)

    let remaining = sut.activeNotifications().currentValue
    #expect(remaining == [notification2])
  }
}
