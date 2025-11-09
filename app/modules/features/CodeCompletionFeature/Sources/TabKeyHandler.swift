// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

// Adapted from CopilotForXcode's TabToAcceptSuggestion.swift

import AppKit
import Foundation

/// Handles Tab key presses to accept code completion suggestions.
/// Uses low-level CGEvent monitoring to intercept Tab key before it reaches Xcode.
final class TabKeyHandler {

  init(
    acceptSuggestion: @escaping () -> Void,
    shouldAccept: @escaping () -> Bool)
  {
    self.acceptSuggestion = acceptSuggestion
    self.shouldAccept = shouldAccept
  }

  deinit {
    stop()
  }

  /// Start monitoring for Tab key presses
  func start() {
    guard eventTap == nil else { return }

    let eventMask = (1 << CGEventType.keyDown.rawValue)

    guard
      let tap = CGEvent.tapCreate(
        tap: .cghidEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(eventMask),
        callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
          guard let refcon else { return Unmanaged.passUnretained(event) }

          let handler = Unmanaged<TabKeyHandler>.fromOpaque(refcon).takeUnretainedValue()
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

  /// Stop monitoring for Tab key presses
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
  private let acceptSuggestion: () -> Void
  private let shouldAccept: () -> Bool

  private func handleEvent(proxy _: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    // Handle tap disabled events
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let tap = eventTap {
        CGEvent.tapEnable(tap: tap, enable: true)
      }
      return Unmanaged.passUnretained(event)
    }

    // Check if it's a Tab key press (keycode 48)
    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    guard keycode == 48 else {
      return Unmanaged.passUnretained(event)
    }

    // Ignore Tab with modifiers
    let flags = event.flags
    if
      flags.contains(.maskShift) ||
      flags.contains(.maskControl) ||
      flags.contains(.maskCommand) ||
      flags.contains(.maskAlternate)
    {
      return Unmanaged.passUnretained(event)
    }

    // Check if we should accept the suggestion
    guard shouldAccept() else {
      return Unmanaged.passUnretained(event)
    }

    // Accept the suggestion and consume the Tab key
    acceptSuggestion()
    return nil // Discard the event
  }
}
