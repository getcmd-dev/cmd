// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
@preconcurrency import Combine
import ConcurrencyFoundation
import LoggingServiceInterface

/// An object that observes an AXUIElement.
/// It will monitor the element's validity and communicate when the element is not valid anymore and the reference needs to be tear down.
class AXElementObserver: @unchecked Sendable {
  @MainActor
  init(element: AXUIElement) {
    self.element = element

    monitorAXUIElementIsValid()
  }

  /// The accessibility element being observed.
  let element: AXUIElement

  @MainActor
  var onElementInvalidated: @Sendable @MainActor (AXElementObserver) -> Void {
    get { internalState.value.onElementInvalidated }
    set { internalState.mutate { $0.onElementInvalidated = newValue } }
  }

  /// Whether the AX element, or all the AX elements referenced by this observer are valid.
  /// When an element becomes stale, it will stop sending notifications.
  var isElementValid: Bool {
    internalState.value.isValid
  }

  /// Attach to the observer a task that will be executed when it is de-referenced.
  func set(cleanupTask: AnyCancellable) {
    internalState.mutate { $0.cleanupTask = cleanupTask }
  }

  private struct InternalState: Sendable {
    var cleanupTask: AnyCancellable?
    var isValid = true
    var onElementInvalidated: @Sendable @MainActor (AXElementObserver) -> Void = { _ in }
  }

  private let internalState = Atomic(InternalState())

  @MainActor
  private func monitorAXUIElementIsValid() {
    if !element.isValid {
      let wasValid = internalState.mutate { state in
        let wasValid = state.isValid
        state.isValid = false
        return wasValid
      }

      if wasValid {
        onElementInvalidated(self)
      }
      return
    }

    Task { [weak self] in
      try await Task.sleep(nanoseconds: 1_000_000_000)
      self?.monitorAXUIElementIsValid()
    }
  }

}
