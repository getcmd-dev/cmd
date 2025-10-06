// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import AppKit
@preconcurrency import Combine
import ConcurrencyFoundation
@preconcurrency import Foundation
import LoggingServiceInterface
import ThreadSafe

// MARK: - AXNotificationPublisher

/// Subscribe to a set of AX notifications provided by an AX element or application,
/// and return them through a Publisher.
@ThreadSafe
public final class AXNotificationPublisher: Publisher, Sendable {

  deinit {
    onDeinit?()
  }

  @MainActor
  public convenience init(
    app: NSRunningApplication,
    element: AXUIElement? = nil,
    notificationNames: String...) // TODO: use typed objects
    throws
  {
    try self.init(
      app: app,
      element: element,
      notificationNames: notificationNames)
  }

  @MainActor
  public init(
    app: NSRunningApplication,
    element: AXUIElement?,
    notificationNames: [String])
    throws
  {
    try setUp(app: app, element: element, notificationNames: notificationNames)
  }

  public typealias Element = (name: String, element: AXUIElement, info: CFDictionary)

  public typealias Output = Element
  public typealias Failure = Never

  public func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Element == S.Input {
    let subscription = RetainingSubscription(
      retained: self,
      publisher: passthroughSubject,
      subscriber: subscriber)
    subscriber.receive(subscription: subscription)
  }

  let passthroughSubject = PassthroughSubject<Element, Never>()

  private var cancellables = Set<AnyCancellable>()

  private var onDeinit: (@Sendable () -> Void)?

  private func setUp(
    app: NSRunningApplication,
    element: AXUIElement?,
    notificationNames: [String])
    throws
  {
    let mode = CFRunLoopMode.commonModes

    let runLoop: CFRunLoop = CFRunLoopGetMain()
    var observer: AXObserver?

    func callback(
      observer _: AXObserver,
      element: AXUIElement,
      notificationName: CFString,
      userInfo: CFDictionary,
      pointer: UnsafeMutableRawPointer?)
    {
      guard let pointer = pointer?.assumingMemoryBound(to: PassthroughSubject<Element, Never>.self)
      else { return }
      pointer.pointee.send((notificationName as String, element, userInfo))
    }

    let error = AXObserverCreateWithInfoCallback(
      app.processIdentifier,
      callback,
      &observer)
    if error != .success {
      logger.error(error)
    }
    guard let observer else {
      logger.error("Failed to create AX notification observer")
      throw AppError(message: "Failed to create AX notification observer")
    }

    let observingElement = element ?? AXUIElementCreateApplication(app.processIdentifier)
    onDeinit = {
      for name in notificationNames {
        AXObserverRemoveNotification(observer, observingElement, name as CFString)
      }
      CFRunLoopRemoveSource(
        runLoop,
        AXObserverGetRunLoopSource(observer),
        mode)
    }

    registerForNotifications(
      notificationNames: notificationNames,
      runLoop: runLoop,
      mode: mode,
      observingElement: observingElement,
      observer: observer)
  }

  private func registerForNotifications(
    notificationNames: [String],
    runLoop: CFRunLoop,
    mode: CFRunLoopMode?,
    observingElement: AXUIElement,
    observer: AXObserver)
  {
    Task { @MainActor [weak self] in
      CFRunLoopAddSource(
        runLoop,
        AXObserverGetRunLoopSource(observer),
        mode)
      var pendingRegistrationNames = Set(notificationNames)
      var retry = 0
      while !pendingRegistrationNames.isEmpty, retry < 100 {
        guard let self else { return }
        retry += 1
        for name in notificationNames {
          await Task.yield()
          var subject = PassthroughSubject<Element, Never>()
          let e = withUnsafeMutablePointer(to: &subject) { pointer in
            AXObserverAddNotification(
              observer,
              observingElement,
              name as CFString,
              pointer)
          }
          let cancellable = subject.sink { [weak self] value in self?.passthroughSubject.send(value) }
          cancellables.insert(AnyCancellable {
            cancellable.cancel()
            _ = subject // ensure that the subject is retained for the lifetime of the publisher.
          })

          switch e {
          case .success:
            pendingRegistrationNames.remove(name)

          case .actionUnsupported:
            logger.info("AXObserver: Action unsupported: \(name)")
            pendingRegistrationNames.remove(name)

          case .apiDisabled:
            logger
              .error("AXObserver: Accessibility API disabled, will try again later")
            retry -= 1

          case .invalidUIElement:
//            logger
//              .info("AXObserver: Invalid UI element, notification name \(name)")
            pendingRegistrationNames.remove(name)

          case .invalidUIElementObserver:
            logger.info("AXObserver: Invalid UI element observer")
            pendingRegistrationNames.remove(name)

          case .cannotComplete:
            logger
              .info("AXObserver: Failed to observe \(name), will try again later")

          case .notificationUnsupported:
            logger.info("AXObserver: Notification unsupported: \(name)")
            pendingRegistrationNames.remove(name)

          case .notificationAlreadyRegistered:
            logger.info("AXObserver: Notification already registered: \(name)")
            pendingRegistrationNames.remove(name)

          default:
            logger
              .info(
                "AXObserver: Unrecognized error \(e) when registering \(name), will try again later")
          }
        }
        try await Task.sleep(nanoseconds: 1_500_000_000)
      }
    }
  }

}
