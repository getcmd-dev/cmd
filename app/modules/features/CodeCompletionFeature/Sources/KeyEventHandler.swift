// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

// Adapted from CopilotForXcode's TabToAcceptSuggestion.swift

import AppKit
import Foundation

// MARK: - KeyEventHandler.Configuration

extension KeyEventHandler {
  /// Configuration for key event monitoring
  struct Configuration {
    /// The key code to monitor (e.g., 48 for Tab, 36 for Return)
    let keyCode: Int64

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
    static func key(_ keyCode: Int64, allowModifiers: Bool = false) -> Configuration {
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
/// Uses low-level CGEvent monitoring to intercept keys before they reach Xcode.
///
/// The handler can be configured to:
/// - Monitor any key code
/// - Respond to key down and/or key up events
/// - Allow or block modifier keys
final class KeyEventHandler {

  init(configuration: Configuration, callbacks: Callbacks) {
    self.configuration = configuration
    self.callbacks = callbacks

    start()
  }

  deinit {
    stop()
  }

  /// Callbacks for key events
  struct Callbacks {
    init(
      onKeyDown: (() -> Void)? = nil,
      onKeyUp: ((_ isDoubleTap: Bool) -> Void)? = nil,
      onDoubleTap: (() -> Void)? = nil,
      doubleTapInterval: TimeInterval = 0.3,
      shouldHandle: @escaping () -> Bool)
    {
      self.onKeyDown = onKeyDown
      self.onKeyUp = onKeyUp
      self.onDoubleTap = onDoubleTap
      self.doubleTapInterval = doubleTapInterval
      self.shouldHandle = shouldHandle
    }

    /// Called when a key down event occurs (if monitored)
    let onKeyDown: (() -> Void)?

    /// Called when a key up event occurs (if monitored)
    /// Parameter indicates whether this is part of a double-tap sequence
    let onKeyUp: ((_ isDoubleTap: Bool) -> Void)?

    /// Called when a double-tap is detected (two rapid key presses)
    /// Only works when onKeyUp is monitored
    let onDoubleTap: (() -> Void)?

    /// Maximum time interval (in seconds) between taps to be considered a double-tap
    /// Default is 0.3 seconds
    let doubleTapInterval: TimeInterval

    /// Called before processing event to determine if it should be handled
    /// Return true to handle the event, false to pass it through
    let shouldHandle: () -> Bool

  }

  /// Start monitoring for key events
  func start() {
    guard eventTap == nil else { return }

    // Infer which events to monitor based on provided callbacks
    var eventMask: CGEventMask = 0

    // Modifier keys use flagsChanged instead of keyDown/keyUp
    if configuration.isModifierKey {
      if callbacks.onKeyDown != nil || callbacks.onKeyUp != nil {
        eventMask |= (1 << CGEventType.flagsChanged.rawValue)
      }
    } else {
      if callbacks.onKeyDown != nil {
        eventMask |= (1 << CGEventType.keyDown.rawValue)
      }
      if callbacks.onKeyUp != nil {
        eventMask |= (1 << CGEventType.keyUp.rawValue)
      }
    }

    guard eventMask != 0 else {
      // No event callbacks configured for monitoring
      return
    }

    guard
      let tap = CGEvent.tapCreate(
        tap: .cghidEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: eventMask,
        callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
          guard let refcon else { return Unmanaged.passUnretained(event) }

          let handler = Unmanaged<KeyEventHandler>.fromOpaque(refcon).takeUnretainedValue()
          return handler.handleEvent(proxy: proxy, type: type, event: event)
        },
        userInfo: Unmanaged.passUnretained(self).toOpaque())
    else {
      print("Failed to create event tap. Make sure accessibility permissions are granted.")
      return
    }

    eventTap = tap
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

    if let source = runLoopSource {
      CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
      CGEvent.tapEnable(tap: tap, enable: true)
    }
  }

  /// Stop monitoring for key events
  func stop() {
    if let tap = eventTap {
      CGEvent.tapEnable(tap: tap, enable: false)
      if let source = runLoopSource {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
      }
      CFMachPortInvalidate(tap)
    }
    eventTap = nil
    runLoopSource = nil
  }

  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private let configuration: Configuration
  private let callbacks: Callbacks
  /// Track whether the monitored modifier key is currently pressed
  private var modifierKeyPressed = false
  /// Track the last time the key was released for double-tap detection
  private var lastKeyUpTime: Date?

  private func handleEvent(proxy _: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    // Handle tap disabled events
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let tap = eventTap {
        CGEvent.tapEnable(tap: tap, enable: true)
      }
      return Unmanaged.passUnretained(event)
    }

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

    // Check if we should handle this event
    guard callbacks.shouldHandle() else {
      return Unmanaged.passUnretained(event)
    }

    // Determine which callback to invoke based on event type
    let shouldConsume: Bool
    switch type {
    case .keyDown:
      if let onKeyDown = callbacks.onKeyDown {
        onKeyDown()
        shouldConsume = true
      } else {
        shouldConsume = false
      }

    case .keyUp:
      // Check for double-tap before calling onKeyUp
      let now = Date()
      if
        let lastTime = lastKeyUpTime,
        let onDoubleTap = callbacks.onDoubleTap,
        now.timeIntervalSince(lastTime) <= callbacks.doubleTapInterval
      {
        // This is a double-tap
        onDoubleTap()
        // Reset timer to prevent triple-tap from triggering another double-tap
        lastKeyUpTime = nil
        shouldConsume = true
      } else {
        // Not a double-tap - call onKeyUp if it exists
        lastKeyUpTime = now

        if let onKeyUp = callbacks.onKeyUp {
          onKeyUp(false)
          shouldConsume = true
        } else {
          shouldConsume = false
        }
      }

    default:
      shouldConsume = false
    }

    // Return nil to consume the event, or pass it through
    return shouldConsume ? nil : Unmanaged.passUnretained(event)
  }

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

    // Check if we should handle this event
    guard callbacks.shouldHandle() else {
      return Unmanaged.passUnretained(event)
    }

    // Detect transition (pressed -> released or released -> pressed)
    let shouldConsume: Bool
    if isPressed, !modifierKeyPressed {
      // Key was just pressed
      modifierKeyPressed = true
      if let onKeyDown = callbacks.onKeyDown {
        onKeyDown()
        shouldConsume = true
      } else {
        shouldConsume = false
      }
    } else if !isPressed, modifierKeyPressed {
      // Key was just released - check for double-tap
      modifierKeyPressed = false

      let now = Date()
      if
        let lastTime = lastKeyUpTime,
        let onDoubleTap = callbacks.onDoubleTap,
        now.timeIntervalSince(lastTime) <= callbacks.doubleTapInterval
      {
        // This is a double-tap
        onDoubleTap()
        lastKeyUpTime = nil
        shouldConsume = true
      } else {
        // Not a double-tap - call onKeyUp if it exists
        lastKeyUpTime = now

        if let onKeyUp = callbacks.onKeyUp {
          onKeyUp(false)
          shouldConsume = true
        } else {
          shouldConsume = false
        }
      }
    } else {
      // No transition, ignore
      shouldConsume = false
    }

    // Return nil to consume the event, or pass it through
    return shouldConsume ? nil : Unmanaged.passUnretained(event)
  }
}
