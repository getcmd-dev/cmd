// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

// Adapted from CopilotForXcode's TabToAcceptSuggestion.swift

@preconcurrency import AppKit
@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import LoggingServiceInterface
import ThreadSafe
import XcodeObserverServiceInterface

// MARK: - KeyEventHandlerManager

/// Manager for handling key events across multiple keys with a single CGEvent tap
@ThreadSafe
final class KeyEventHandlerManager: @unchecked Sendable {

  init(appsActivationState: ReadonlyCurrentValueSubject<AppsActivationState>) {
    self.appsActivationState = appsActivationState

    observeXcodeActivationStateChanges()
  }

  var isXcodeActive: Bool {
    appsActivationState.value.isXcodeActive
  }

  /// Register a listener for a specific key code
  @MainActor
  func register(configuration: KeyEventHandler.Configuration, callbacks: KeyEventHandler.Callbacks) -> KeyEventListener {
    let listener = KeyEventListener(configuration: configuration, callbacks: callbacks)
    listeners[configuration.keyCode] = listener
    ensureTapIsRunning()
    return listener
  }

  /// Unregister a listener for a specific key code
  func unregister(keyCode: Int) {
    listeners.removeValue(forKey: keyCode)
    if listeners.isEmpty {
      stopTap()
    }
  }

  private let appsActivationState: ReadonlyCurrentValueSubject<AppsActivationState>
  private var cancellables = Set<AnyCancellable>()

  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var runLoop: CFRunLoop?
  private var listeners = [Int: KeyEventListener]()

  /// Moved out of the initializer to work around a compiler bug.
  private func observeXcodeActivationStateChanges() {
    appsActivationState.sink { @Sendable [weak self] value in
      runOnMainThread {
        if value.isXcodeActive {
          self?.ensureTapIsRunning()
        } else {
          self?.stopTap()
        }
      }
    }.store(in: &cancellables)
  }

  @MainActor
  private func ensureTapIsRunning() {
    guard eventTap == nil else { return }

    // Create event mask for all events we might need
    var eventMask: CGEventMask = 0
    eventMask |= (1 << CGEventType.keyDown.rawValue)
    eventMask |= (1 << CGEventType.keyUp.rawValue)
    eventMask |= (1 << CGEventType.flagsChanged.rawValue)

    guard
      let tap = CGEvent.tapCreate(
        tap: .cghidEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: eventMask,
        callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
          let d = Date()
          guard let refcon else {
            return Unmanaged.passUnretained(event)
          }

          let manager = Unmanaged<KeyEventHandlerManager>.fromOpaque(refcon).takeUnretainedValue()

          // Check if Xcode is active before processing any events
          guard manager.isXcodeActive else {
            return Unmanaged.passUnretained(event)
          }

          let result = manager.handleEvent(proxy: proxy, type: type, event: event)

          performanceLogger
            .trace(
              "key handled in \(Date().timeIntervalSince(d)) at \(Date().timeIntervalSince1970). Intercepting: \(result == nil)")
          return result
        },
        userInfo: Unmanaged.passUnretained(self).toOpaque())
    else {
      return
    }

    eventTap = tap
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    runLoop = CFRunLoopGetCurrent()

    if let source = runLoopSource, let runLoop {
      CFRunLoopAddSource(runLoop, source, .commonModes)
      CGEvent.tapEnable(tap: tap, enable: true)
    }
  }

  private func stopTap() {
    if let tap = eventTap {
      CGEvent.tapEnable(tap: tap, enable: false)
      if let source = runLoopSource, let runLoop {
        CFRunLoopRemoveSource(runLoop, source, .commonModes)
      }
      CFMachPortInvalidate(tap)
    }
    eventTap = nil
    runLoopSource = nil
    runLoop = nil
  }

  private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    // Handle tap disabled events
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let tap = eventTap {
        CGEvent.tapEnable(tap: tap, enable: true)
      }
      return Unmanaged.passUnretained(event)
    }

    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    guard let listener = listeners[Int(keycode)] else {
      return Unmanaged.passUnretained(event)
    }

    return listener.handleEvent(proxy: proxy, type: type, event: event)
  }
}

// MARK: - KeyEventListener

/// Listener for a specific key's events
@ThreadSafe
final class KeyEventListener: Sendable {
  init(configuration: KeyEventHandler.Configuration, callbacks: KeyEventHandler.Callbacks) {
    self.configuration = configuration
    self.callbacks = callbacks
  }

  let configuration: KeyEventHandler.Configuration
  let callbacks: KeyEventHandler.Callbacks

  func handleEvent(proxy _: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    // Handle flagsChanged for modifier keys
    if type == .flagsChanged, configuration.isModifierKey {
      return handleModifierFlagsChanged(event: event)
    }

    // Check if it's the configured key
    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    guard keycode == configuration.keyCode else {
      return Unmanaged.passUnretained(event)
    }

    // Check modifiers if needed (skip if we're monitoring a modifier key itself)
    if !configuration.allowModifiers, !configuration.isModifierKey {
      let flags = event.flags
      if
        flags.contains(.maskShift) ||
        flags.contains(.maskControl) ||
        flags.contains(.maskCommand) ||
        flags.contains(.maskAlternate)
      {
        return Unmanaged.passUnretained(event)
      }
    }

    // Determine which callback to invoke based on event type
    let shouldConsume: Bool
    let flags = event.flags
    switch type {
    case .keyDown:
      if let onKeyDown = callbacks.onKeyDown {
        shouldConsume = onKeyDown(false, flags)
      } else {
        shouldConsume = false
      }

    case .keyUp:
      // Check for double-tap
      let now = Date()
      let isDoubleTap =
        if
          let lastTime = lastKeyUpTime,
          now.timeIntervalSince(lastTime) <= callbacks.doubleTapInterval
        {
          true
        } else {
          false
        }

      if isDoubleTap {
        // This is a double-tap
        // Reset timer to prevent triple-tap from triggering another double-tap
        lastKeyUpTime = nil
        // Call onKeyUp with isDoubleTap=true to let it decide if it wants to consume
        if let onKeyUp = callbacks.onKeyUp {
          shouldConsume = onKeyUp(true, flags)
        } else {
          shouldConsume = false
        }
      } else {
        // Not a double-tap - call onKeyUp if it exists
        if let onKeyUp = callbacks.onKeyUp {
          shouldConsume = onKeyUp(false, flags)
        } else {
          shouldConsume = false
        }
        // Always update lastKeyUpTime for non-double-tap to track future double-taps
        lastKeyUpTime = now
      }

    default:
      shouldConsume = false
    }

    // Return nil to consume the event, or pass it through
    return shouldConsume ? nil : Unmanaged.passUnretained(event)
  }

  /// Track whether the monitored modifier key is currently pressed
  private var modifierKeyPressed = false
  /// Track the last time the key was released for double-tap detection
  private var lastKeyUpTime: Date?

  private func handleModifierFlagsChanged(event: CGEvent) -> Unmanaged<CGEvent>? {
    let flags = event.flags

    // Determine which modifier flag corresponds to our key code
    let isPressed: Bool
    switch configuration.keyCode {
    case 54, 55: // Command keys
      isPressed = flags.contains(.maskCommand)

    case 56, 60: // Shift keys
      isPressed = flags.contains(.maskShift)

    case 58, 61: // Option keys
      isPressed = flags.contains(.maskAlternate)

    case 59, 62: // Control keys
      isPressed = flags.contains(.maskControl)

    default:
      // Unknown modifier key
      return Unmanaged.passUnretained(event)
    }

    // Detect transition (pressed -> released or released -> pressed)
    let shouldConsume: Bool
    if isPressed, !modifierKeyPressed {
      // Key was just pressed
      modifierKeyPressed = true
      if let onKeyDown = callbacks.onKeyDown {
        shouldConsume = onKeyDown(false, flags)
      } else {
        shouldConsume = false
      }
    } else if !isPressed, modifierKeyPressed {
      // Key was just released - check for double-tap
      modifierKeyPressed = false

      let now = Date()
      let isDoubleTap =
        if
          let lastTime = lastKeyUpTime,
          now.timeIntervalSince(lastTime) <= callbacks.doubleTapInterval
        {
          true
        } else {
          false
        }

      if isDoubleTap {
        // This is a double-tap
        lastKeyUpTime = nil
        // Call onKeyUp with isDoubleTap=true to let it decide if it wants to consume
        if let onKeyUp = callbacks.onKeyUp {
          shouldConsume = onKeyUp(true, flags)
        } else {
          shouldConsume = false
        }
      } else {
        // Not a double-tap - call onKeyUp if it exists
        if let onKeyUp = callbacks.onKeyUp {
          shouldConsume = onKeyUp(false, flags)
        } else {
          shouldConsume = false
        }
        // Always update lastKeyUpTime for non-double-tap to track future double-taps
        lastKeyUpTime = now
      }
    } else {
      // No transition, ignore
      shouldConsume = false
    }

    // Return nil to consume the event, or pass it through
    return shouldConsume ? nil : Unmanaged.passUnretained(event)
  }
}

// MARK: - KeyEventHandler.Configuration

/// Configuration for KeyEventHandler
extension KeyEventHandler {
  /// Configuration for key event monitoring
  struct Configuration: Sendable {
    /// The key code to monitor (e.g., 48 for Tab, 36 for Return)
    let keyCode: Int

    /// Whether to allow modifier keys (Shift, Control, Command, Option)
    /// When false, events with any modifiers will be ignored
    let allowModifiers: Bool

    /// Check if this key code is a modifier key
    var isModifierKey: Bool {
      // Modifier key codes:
      // 54 = Right Command, 55 = Left Command
      // 56 = Left Shift, 60 = Right Shift
      // 58 = Left Option, 61 = Right Option
      // 59 = Left Control, 62 = Right Control
      // 57 = Caps Lock, 63 = Function
      [54, 55, 56, 58, 59, 60, 61, 62, 57, 63].contains(keyCode)
    }

    /// Creates a configuration for a specific key code
    static func key(_ keyCode: Int, allowModifiers: Bool = false) -> Configuration {
      Configuration(keyCode: keyCode, allowModifiers: allowModifiers)
    }

    /// Creates a configuration for Tab key (key code 48)
    static func tab(allowModifiers: Bool = false) -> Configuration {
      .key(48, allowModifiers: allowModifiers)
    }

    /// Creates a configuration for Escape key (key code 53)
    static func escape(allowModifiers: Bool = false) -> Configuration {
      .key(53, allowModifiers: allowModifiers)
    }

    /// Creates a configuration for Command key (key code 55 for left, 54 for right)
    static func command(allowModifiers: Bool = false, useRightCommand: Bool = false) -> Configuration {
      .key(useRightCommand ? 54 : 55, allowModifiers: allowModifiers)
    }
  }
}

// MARK: - KeyEventHandler

/// Handles keyboard events to accept code completion suggestions.
/// Uses a KeyEventHandlerManager to process events with a single CGEvent tap.
///
/// The handler can be configured to:
/// - Monitor any key code
/// - Respond to key down and/or key up events
/// - Allow or block modifier keys
final class KeyEventHandler {

  init(manager: KeyEventHandlerManager, configuration: Configuration, callbacks: Callbacks) {
    self.manager = manager
    self.configuration = configuration
    self.callbacks = callbacks
  }

  deinit {
    stop()
  }

  /// Callbacks for key events
  /// IMPORTANT: These callbacks run synchronously on the CGEvent callback thread, NOT on the main actor.
  /// They must return quickly (ideally < 1ms) to avoid blocking keyboard input.
  /// Any side effects should be dispatched to the main actor asynchronously.
  struct Callbacks: Sendable {
    init(
      onKeyDown: (@Sendable (_ isDoubleTap: Bool, _ modifiers: CGEventFlags) -> Bool)? = nil,
      onKeyUp: (@Sendable (_ isDoubleTap: Bool, _ modifiers: CGEventFlags) -> Bool)? = nil,
      doubleTapInterval: TimeInterval = 0.3)
    {
      self.onKeyDown = onKeyDown
      self.onKeyUp = onKeyUp
      self.doubleTapInterval = doubleTapInterval
    }

    /// Called when a key down event occurs (if monitored)
    /// Parameters:
    /// - isDoubleTap: Whether this is part of a double-tap sequence
    /// - modifiers: The modifier flags (Command, Shift, Option, Control) active during the event
    /// Return true to consume the event, false to pass it through
    let onKeyDown: (@Sendable (_ isDoubleTap: Bool, _ modifiers: CGEventFlags) -> Bool)?

    /// Called when a key up event occurs (if monitored)
    /// Parameters:
    /// - isDoubleTap: Whether this is part of a double-tap sequence
    /// - modifiers: The modifier flags (Command, Shift, Option, Control) active during the event
    /// Return true to consume the event, false to pass it through
    let onKeyUp: (@Sendable (_ isDoubleTap: Bool, _ modifiers: CGEventFlags) -> Bool)?

    /// Maximum time interval (in seconds) between taps to be considered a double-tap
    /// Default is 0.3 seconds
    let doubleTapInterval: TimeInterval

  }

  /// Start monitoring for key events
  @MainActor
  func start() {
    guard listener == nil else { return }
    listener = manager.register(configuration: configuration, callbacks: callbacks)
  }

  /// Stop monitoring for key events
  func stop() {
    if listener != nil {
      manager.unregister(keyCode: configuration.keyCode)
      listener = nil
    }
  }

  private let manager: KeyEventHandlerManager

  private var listener: KeyEventListener?
  private let configuration: Configuration
  private let callbacks: Callbacks
}
