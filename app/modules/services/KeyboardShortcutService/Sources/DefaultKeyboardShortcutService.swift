// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
@preconcurrency import Combine
import DependencyFoundation
import Foundation
import KeyboardShortcuts
import KeyboardShortcutServiceInterface
import LoggingServiceInterface
import SwiftUI
import ThreadSafe
import XcodeObserverServiceInterface

// MARK: - DefaultKeyboardShortcutService

@ThreadSafe
final class DefaultKeyboardShortcutService: KeyboardShortcutService, @unchecked Sendable {
  init(appsActivationState: ReadonlyCurrentValueSubject<AppsActivationState, Never>) {
    observeActivationState(appsActivationState: appsActivationState)
  }

  func registerShortcut(
    name: String,
    _ key: Key,
    modifiers: NSEvent.ModifierFlags,
    activationCondition: KeyboardShortcutActivationCondition,
    action: @escaping @Sendable () async -> Void)
    -> AnyCancellable
  {
    let id = UUID()
    let shortcut = KeyboardShortcuts.Name(name, default: .init(key, modifiers: modifiers))
    shortcuts[id] = shortcut

    KeyboardShortcuts.onKeyUp(for: shortcut) { @Sendable [weak self] in
      Task {
        guard let self else { return }
        if self.enabledShortcutNames.contains(shortcut.rawValue) {
          await action()
        }
      }
    }

    switch activationCondition {
    case .always:
      alwaysOnShortcuts.insert(id)
    case .eitherActive:
      eitherShortcuts.insert(id)
    case .hostAppActive:
      appShortcuts.insert(id)
    case .xcodeActive:
      xcodeShortcuts.insert(id)
    }

    switch appsActivationState {
    case .bothActive:
      if
        eitherShortcuts.contains(id) || appShortcuts.contains(id) || xcodeShortcuts.contains(id) || alwaysOnShortcuts
          .contains(id)
      {
        enable([shortcut])
      }

    case .hostAppActive:
      if eitherShortcuts.contains(id) || appShortcuts.contains(id) || alwaysOnShortcuts.contains(id) {
        enable([shortcut])
      }

    case .xcodeActive:
      if eitherShortcuts.contains(id) || xcodeShortcuts.contains(id) || alwaysOnShortcuts.contains(id) {
        enable([shortcut])
      }

    case .inactive, .none:
      if alwaysOnShortcuts.contains(id) {
        enable([shortcut])
      }
    }

    return AnyCancellable { [weak self] in
      guard let self else { return }
      inLock { state in
        state.shortcuts.removeValue(forKey: id)
        state.alwaysOnShortcuts.remove(id)
        state.eitherShortcuts.remove(id)
        state.appShortcuts.remove(id)
        state.xcodeShortcuts.remove(id)
      }
    }
  }

  private var alwaysOnShortcuts = Set<UUID>()
  private var xcodeShortcuts = Set<UUID>()
  private var appShortcuts = Set<UUID>()
  private var eitherShortcuts = Set<UUID>()
  private var shortcuts = [UUID: KeyboardShortcuts.Name]()
  private var appsActivationState: AppsActivationState?

  private var cancellables = Set<AnyCancellable>()

  private var enabledShortcutNames = Set<String>()

  /// This can be moved to the initializer once https://github.com/swiftlang/swift/issues/80050 is fixed.
  private func observeActivationState(appsActivationState: ReadonlyCurrentValueSubject<AppsActivationState, Never>) {
    let cancellable = appsActivationState
      .sink { @Sendable [weak self] appsActivationState in
        guard let self else { return }
        self.appsActivationState = appsActivationState
        // Handle de-activations first, then activations.
        if !appsActivationState.isHostAppActive {
          disable(eitherShortcuts.compactMap({ shortcuts[$0] }))
          disable(appShortcuts.compactMap({ shortcuts[$0] }))
        }
        if !appsActivationState.isXcodeActive {
          disable(eitherShortcuts.compactMap({ shortcuts[$0] }))
          disable(xcodeShortcuts.compactMap({ shortcuts[$0] }))
        }
        if appsActivationState.isHostAppActive {
          enable(eitherShortcuts.compactMap({ shortcuts[$0] }))
          enable(appShortcuts.compactMap({ shortcuts[$0] }))
        }
        if appsActivationState.isXcodeActive {
          enable(eitherShortcuts.compactMap({ shortcuts[$0] }))
          enable(xcodeShortcuts.compactMap({ shortcuts[$0] }))
        }
      }
    cancellables.insert(cancellable)
  }

  /// Manually tracks enabled shortcuts due to https://github.com/sindresorhus/KeyboardShortcuts/issues/217
  private func enable(_ shortcuts: [KeyboardShortcuts.Name]) {
    KeyboardShortcuts.enable(shortcuts)
    inLock { state in
      for shortcut in shortcuts { state.enabledShortcutNames.insert(shortcut.rawValue) }
    }
  }

  private func disable(_ shortcuts: [KeyboardShortcuts.Name]) {
    KeyboardShortcuts.disable(shortcuts)
    inLock { state in
      for shortcut in shortcuts { state.enabledShortcutNames.remove(shortcut.rawValue) }
    }
  }

}

extension BaseProviding where Self: AppsActivationStateProviding {
  public var keyboardShortcutService: KeyboardShortcutService {
    shared {
      DefaultKeyboardShortcutService(appsActivationState: appsActivationState)
    }
  }
}

extension KeyboardShortcuts.Key {
  init?(character key: Character) {
    switch key {
    case "a": self = .a
    case "b": self = .b
    case "c": self = .c
    case "d": self = .d
    case "e": self = .e
    case "f": self = .f
    case "g": self = .g
    case "h": self = .h
    case "i": self = .i
    case "j": self = .j
    case "k": self = .k
    case "l": self = .l
    case "m": self = .m
    case "n": self = .n
    case "o": self = .o
    case "p": self = .p
    case "q": self = .q
    case "r": self = .r
    case "s": self = .s
    case "t": self = .t
    case "u": self = .u
    case "v": self = .v
    case "w": self = .w
    case "x": self = .x
    case "y": self = .y
    case "z": self = .z
    case "0": self = .zero
    case "1": self = .one
    case "2": self = .two
    case "3": self = .three
    case "4": self = .four
    case "5": self = .five
    case "6": self = .six
    case "7": self = .seven
    case "8": self = .eight
    case "9": self = .nine
    case KeyEquivalent.upArrow.character: self = .upArrow
    case KeyEquivalent.downArrow.character: self = .downArrow
    case KeyEquivalent.leftArrow.character: self = .leftArrow
    case KeyEquivalent.rightArrow.character: self = .rightArrow
    case KeyEquivalent.escape.character: self = .escape
    case KeyEquivalent.delete.character: self = .delete
    case KeyEquivalent.deleteForward.character: self = .deleteForward
    case KeyEquivalent.home.character: self = .home
    case KeyEquivalent.end.character: self = .end
    case KeyEquivalent.pageUp.character: self = .pageUp
    case KeyEquivalent.pageDown.character: self = .pageDown
    case KeyEquivalent.tab.character: self = .tab
    case KeyEquivalent.space.character: self = .space
    case KeyEquivalent.`return`.character: self = .`return`
    default:
      return nil
    }
  }
}
