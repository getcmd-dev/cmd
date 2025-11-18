// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import Combine
import Foundation
import ThreadSafe

#if DEBUG
@ThreadSafe
public final class MockKeyboardShortcutService: KeyboardShortcutService {
  public init() {
    onRegisterShortcut = { _, _, _, _, _ in AnyCancellable { } }
  }

  /// For testing: get all registrations
  public var registrations = [Key: [@Sendable () async -> Void]]()

  /// For testing: set the onRegisterShortcut callback
  public var onRegisterShortcut: @Sendable (
    _ name: String,
    _ key: Key,
    _ modifiers: NSEvent.ModifierFlags,
    _ activationCondition: KeyboardShortcutActivationCondition,
    _ action: @escaping @Sendable () async -> Void)
    -> AnyCancellable

  public func registerShortcut(
    name: String,
    _ key: Key,
    modifiers: NSEvent.ModifierFlags,
    activationCondition: KeyboardShortcutActivationCondition,
    action: @escaping @Sendable () async -> Void)
    -> AnyCancellable
  {
    registrations[key] = registrations[key, default: []]
    registrations[key]?.append(action)
    return onRegisterShortcut(name, key, modifiers, activationCondition, action)
  }

  /// For testing: trigger a shortcut by key code and modifiers
  public func triggerShortcut(key: Key) async {
    for callback in registrations[key, default: []] {
      await callback()
    }
  }
}
#endif
