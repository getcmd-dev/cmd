// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppEventServiceInterface
import AppFoundation
import AppKit
import ChatAppEvents
@preconcurrency import Combine
import Dependencies
import KeyboardShortcuts
import SettingsServiceInterface
import SwiftUI
import ThreadSafe
import XcodeObserverServiceInterface

// MARK: - XcodeKeyboardShortcutsManager

// TODO: Remove @unchecked when https://github.com/pointfreeco/swift-dependencies/discussions/267 is fixed
@ThreadSafe
final class XcodeKeyboardShortcutsManager: @unchecked Sendable {

  init(appsActivationState: AnyPublisher<AppsActivationState, Never>) {
    registerActions()

    observeXcodeState(appsActivationState: appsActivationState)
    enable([.hideChat])
    observeSettings()
  }

  private var cancellables: Set<AnyCancellable> = []

  private var enabledShortcutNames = Set<String>()

  @Dependency(\.appEventHandlerRegistry) private var appEventHandlerRegistry
  @Dependency(\.settingsService) private var settingsService

  /// This can be moved to the initializer once https://github.com/swiftlang/swift/issues/80050 is fixed.
  private func observeXcodeState(appsActivationState: AnyPublisher<AppsActivationState, Never>) {
    let cancellable = appsActivationState
      .sink { @Sendable [weak self] appsActivationState in
        guard let self else { return }
        // Handle de-activations first, then activations.
        if !appsActivationState.isHostAppActive {
          disable(KeyboardShortcuts.Name.hostAppShortcuts)
        }
        if !appsActivationState.isXcodeActive {
          disable(KeyboardShortcuts.Name.xcodeShortcuts)
        }
        if appsActivationState.isHostAppActive {
          enable(KeyboardShortcuts.Name.hostAppShortcuts)
        }
        if appsActivationState.isXcodeActive {
          enable(KeyboardShortcuts.Name.xcodeShortcuts)
        }
      }
    inLock { $0.cancellables.insert(cancellable) }
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

  private func registerActions() {
    on(.addContext, trigger: AddCodeToChatEvent(newThread: false, chatMode: nil))
    on(.addContextToNewThread, trigger: AddCodeToChatEvent(newThread: true, chatMode: nil))
    on(.edit, trigger: EditEvent())
    on(.generate, trigger: GenerateEvent())
    on(.hideChat, trigger: HideChatEvent())
    on(.new, trigger: NewChatEvent())
  }

  // MARK: - Settings integration

  /// Observe settings and update the registered keyboard shortcuts when they change.
  private func observeSettings() {
    let cancellable = settingsService
      .liveValue(for: \.keyboardShortcuts)
      .sink { @Sendable [weak self] keyboardShortcutsSettings in
        self?.apply(keyboardShortcutsSettings)
      }
    inLock { $0.cancellables.insert(cancellable) }
  }

  private func apply(_ settings: SettingsServiceInterface.Settings.KeyboardShortcuts) {
    let keyBoardMap: [(SettingsServiceInterface.Settings.KeyboardShortcut, KeyboardShortcuts.Name)] = [
      (settings[withDefault: .addContextToCurrentChat], .addContext),
      (settings[withDefault: .addContextToNewChat], .addContextToNewThread),
      (settings[withDefault: .dismissChat], .hideChat),
    ]
    for (setting, shortcutName) in keyBoardMap {
      KeyboardShortcuts.setShortcut(setting.mapped, for: shortcutName)
    }
  }

  private func on(_ keyEvent: KeyboardShortcuts.Name, trigger event: AppEvent) {
    KeyboardShortcuts.onKeyUp(for: keyEvent) { @Sendable [weak self] in
      Task {
        guard let self else { return }
        if self.enabledShortcutNames.contains(keyEvent.rawValue) {
          _ = await self.appEventHandlerRegistry.handle(event: event)
        }
      }
    }
  }
}

extension KeyboardShortcuts.Name {
  static let hideChat = Self("hideChat", default: .init(.escape, modifiers: [.command]))
  // Xcode shortcuts
  static let addContext = Self("addContext", default: .init(.i, modifiers: [.command]))
  static let addContextToNewThread = Self("addContextToNewThread", default: .init(.i, modifiers: [.command, .shift]))
  static let edit = Self("edit", default: .init(.k, modifiers: [.command, .shift]))
  static let generate = Self("generate", default: .init(.k, modifiers: [.command]))

  static let xcodeShortcuts = [
    Self.addContext,
    Self.addContextToNewThread,
    Self.edit,
    Self.generate,
  ]
  /// Host app shortcuts
  static let new = Self("new", default: .init(.n, modifiers: [.command]))

  static let hostAppShortcuts = [
    Self.new,
  ]
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

extension SettingsServiceInterface.Settings.KeyboardShortcut {
  var mapped: KeyboardShortcuts.Shortcut? {
    guard let key = KeyboardShortcuts.Key(character: key.character) else { return nil }
    return KeyboardShortcuts.Shortcut(key, modifiers: modifiers.nsEventModifierFlags)
  }
}
