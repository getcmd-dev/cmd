// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import SwiftUI

// MARK: - KeyModifier

public enum KeyModifier: String, Codable, Sendable {
  case capsLock
  case shift
  case control
  case option
  case command
  case numericPad
  case help
  case function

  public var description: String {
    switch self {
    case .capsLock: "⇪"
    case .shift: "⇧"
    case .control: "⌃"
    case .option: "⌥"
    case .command: "⌘"
    case .numericPad: "Num"
    case .help: "?"
    case .function: "Fn"
    }
  }
}

extension Array where Element == KeyModifier {
  public init(_ modifiers: NSEvent.ModifierFlags) {
    self = []
    if modifiers.contains(.capsLock) { append(.capsLock) }
    if modifiers.contains(.shift) { append(.shift) }
    if modifiers.contains(.control) { append(.control) }
    if modifiers.contains(.option) { append(.option) }
    if modifiers.contains(.command) { append(.command) }
    if modifiers.contains(.numericPad) { append(.numericPad) }
    if modifiers.contains(.help) { append(.help) }
    if modifiers.contains(.function) { append(.function) }
  }

  public var nsEventModifierFlags: NSEvent.ModifierFlags {
    var flags: NSEvent.ModifierFlags = []
    for modifier in self {
      switch modifier {
      case .capsLock: flags.insert(.capsLock)
      case .shift: flags.insert(.shift)
      case .control: flags.insert(.control)
      case .option: flags.insert(.option)
      case .command: flags.insert(.command)
      case .numericPad: flags.insert(.numericPad)
      case .help: flags.insert(.help)
      case .function: flags.insert(.function)
      }
    }
    return flags
  }
}

extension KeyEquivalent {
  public var description: String {
    switch self {
    case .upArrow: "▲"
    case .downArrow: "▼"
    case .leftArrow: "◀"
    case .rightArrow: "▶"
    case .escape: "␛"
    case .delete: "⌫"
    case .deleteForward: "⌦"
    case .home: "↖"
    case .end: "↘"
    case .pageUp: "⇞"
    case .pageDown: "⇟"
    case .clear: "⌧"
    case .tab: "⇥"
    case .space: "␣"
    case .`return`: "⏎"
    default: String(character).uppercased()
    }
  }
}
