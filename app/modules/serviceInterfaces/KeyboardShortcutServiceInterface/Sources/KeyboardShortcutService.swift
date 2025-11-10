// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import Combine
import Foundation
import KeyboardShortcuts

// MARK: - KeyboardShortcutActivationCondition

/// Defines when a keyboard shortcut should be active
public enum KeyboardShortcutActivationCondition: Sendable, Equatable {
  /// Shortcut is active only when Xcode is the frontmost application
  case xcodeActive
  /// Shortcut is active only when the host app is the frontmost application
  case hostAppActive
  /// Shortcut is active when either Xcode or the host app is frontmost
  case eitherActive
  /// Shortcut is always active regardless of app state
  case always
}

// MARK: - KeyboardShortcutService

/// Service for managing keyboard shortcuts
public protocol KeyboardShortcutService: Sendable {
  /// Registers a keyboard shortcut with the specified activation condition
  /// - Parameters:
  ///   - name: An identifier for the shortcut
  ///   - keyCode: The key code for the shortcut
  ///   - modifierFlags: Modifier flags (command, shift, option, control)
  ///   - activationCondition: When the shortcut should be active
  ///   - action: The action to perform when triggered
  /// - Returns: A cancellable that will unregister the shortcut when deallocated
  func registerShortcut(
    name: String,
    _ key: Key,
    modifiers: NSEvent.ModifierFlags,
    activationCondition: KeyboardShortcutActivationCondition,
    action: @escaping @Sendable () async -> Void)
    -> AnyCancellable
}

public typealias Key = KeyboardShortcuts.Key

// MARK: - KeyboardShortcutServiceProviding

public protocol KeyboardShortcutServiceProviding {
  var keyboardShortcutService: KeyboardShortcutService { get }
}
