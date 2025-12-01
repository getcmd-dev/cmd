// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftTesting
import Testing

@testable import PushNotificationServiceInterface

struct MockPushNotificationServiceTests {

  @Test
  func test_sendsNotification() async throws {
    let sut = MockPushNotificationService()
    let exp = expectation(description: "notification sent")

    sut.onSend = { notification in
      #expect(notification.title == "Test Title")
      #expect(notification.body == "Test Body")
      #expect(notification.actions.count == 2)
      #expect(notification.actions[0].title == "Action 1")
      #expect(notification.actions[1].title == "Action 2")
      exp.fulfill()
    }

    let notification = PushNotification(
      title: "Test Title",
      body: "Test Body",
      actions: [
        PushNotificationAction(title: "Action 1", callback: { }),
        PushNotificationAction(title: "Action 2", callback: { }),
      ])

    try await sut.send(notification)
    try await fulfillment(of: exp)

    let count = sut.activeNotificationCount().value
    #expect(count == 1)
  }

  @Test
  func test_handlesActionCallback() async throws {
    let sut = MockPushNotificationService()
    let callbackExp = expectation(description: "action callback executed")

    let action = PushNotificationAction(title: "Action 1", callback: {
      callbackExp.fulfill()
    })

    let notification = PushNotification(title: "Test", body: "Body", actions: [action])
    try await sut.send(notification)

    // Trigger the callback using the internal identifier
    await sut.handleActionCallback(actionIdentifier: action.identifier)

    try await fulfillment(of: callbackExp)
  }

  @Test
  func test_tracksActiveNotifications() async throws {
    let sut = MockPushNotificationService()

    // Send first notification
    try await sut.send(PushNotification(title: "Title 1", body: "Body 1"))

    var count = sut.activeNotificationCount().value
    #expect(count == 1)

    // Send second notification
    try await sut.send(PushNotification(title: "Title 2", body: "Body 2"))

    count = sut.activeNotificationCount().value
    #expect(count == 2)

    let notifications = sut.activeNotifications().value
    #expect(notifications.count == 2)
    #expect(notifications[0].title == "Title 1")
    #expect(notifications[1].title == "Title 2")
  }

  @Test
  func test_clearsAllNotifications() async throws {
    let sut = MockPushNotificationService()
    let exp = expectation(description: "notifications cleared")

    sut.onClearAllNotifications = {
      exp.fulfill()
    }

    // Send notifications
    try await sut.send(PushNotification(title: "Title 1", body: "Body 1"))
    try await sut.send(PushNotification(title: "Title 2", body: "Body 2"))

    var count = sut.activeNotificationCount().value
    #expect(count == 2)

    // Clear all
    await sut.clearAllNotifications()
    try await fulfillment(of: exp)

    count = sut.activeNotificationCount().value
    #expect(count == 0)
  }

  @Test
  func test_clearsSpecificNotification() async throws {
    let sut = MockPushNotificationService()
    let exp = expectation(description: "notification cleared")

    let notification1 = PushNotification(title: "Title 1", body: "Body 1")
    let notification2 = PushNotification(title: "Title 2", body: "Body 2")

    sut.onClear = { notification in
      #expect(notification.id == notification1.id)
      exp.fulfill()
    }

    // Send notifications
    try await sut.send(notification1)
    try await sut.send(notification2)

    let notifications = sut.activeNotifications().value
    #expect(notifications.count == 2)

    // Clear specific notification
    await sut.clear(notification: notification1)
    try await fulfillment(of: exp)

    let remainingCount = sut.activeNotificationCount().value
    #expect(remainingCount == 1)

    let remaining = sut.activeNotifications().value
    #expect(remaining == [notification2])
  }

  @Test
  func test_handleActionCallbackHook() async throws {
    let sut = MockPushNotificationService()
    let hookExp = expectation(description: "onHandleActionCallback called")

    let action = PushNotificationAction(title: "Action 1", callback: { })

    sut.onHandleActionCallback = { identifier in
      #expect(identifier == action.identifier)
      hookExp.fulfill()
    }

    let notification = PushNotification(title: "Test", body: "Body", actions: [action])
    try await sut.send(notification)
    await sut.handleActionCallback(actionIdentifier: action.identifier)

    try await fulfillment(of: hookExp)
  }
}
