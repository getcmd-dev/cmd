// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CoreGraphics
import FileDiffTypesFoundation
import ThreadSafe

// MARK: - KeyEventState

/// Thread-safe state container for key event decision-making.
/// This allows CGEvent callbacks to check state without blocking on the main actor.
@ThreadSafe
final class KeyEventState: Sendable {
  var hasCompletion = false

  var hasEditorState = false

  var isCompletionExpandable = false

  var isAutomaticCompletionEnabled = true

  var multiLineDisplayModeIsAlwaysShown = false

  func update(
    hasCompletion: Bool? = nil,
    hasEditorState: Bool? = nil,
    isCompletionExpandable: Bool? = nil,
    isAutomaticCompletionEnabled: Bool? = nil,
    multiLineDisplayModeIsAlwaysShown: Bool? = nil)
  {
    inLock { state in
      if let hasCompletion { state.hasCompletion = hasCompletion }
      if let hasEditorState { state.hasEditorState = hasEditorState }
      if let isCompletionExpandable { state.isCompletionExpandable = isCompletionExpandable }
      if let isAutomaticCompletionEnabled { state.isAutomaticCompletionEnabled = isAutomaticCompletionEnabled }
      if let multiLineDisplayModeIsAlwaysShown { state.multiLineDisplayModeIsAlwaysShown = multiLineDisplayModeIsAlwaysShown }
    }
  }
}

extension CodeCompletionViewModel {
  func setUpKeyInterception() {
    // Initialize Tab key handler (triggered on key down, allows Command modifier)
    // NOTE: Callbacks run on CGEvent thread - use keyEventState for thread-safe state checks
    completionKeyHandlers.append(KeyEventHandler(
      manager: keyEventHandlerManager,
      configuration: .tab(allowModifiers: true),
      callbacks: .init(
        // interception on key down is needed when ⌘ is held, as otherwise the OS would handle the ⌘ + ⇥ down (cycle through apps).
        onKeyDown: { [keyEventState] _, modifiers in
          guard keyEventState.hasEditorState, keyEventState.hasCompletion else { return false }
          guard modifiers.intersection([.maskShift, .maskControl, .maskSecondaryFn, .maskAlternate]).isEmpty else { return false }
          guard
            !modifiers.contains(.maskCommand) || (keyEventState.isCompletionExpandable &&
              !keyEventState.multiLineDisplayModeIsAlwaysShown)
          else {
            // Only allow Tab key handling if Command is not pressed, or if it is used to expand the completion
            return false
          }
          return true
        },
        onKeyUp: { [weak self, keyEventState] (_: Bool, modifiers: CGEventFlags) in
          guard keyEventState.hasEditorState, keyEventState.hasCompletion else { return false }
          guard modifiers.intersection([.maskShift, .maskControl, .maskSecondaryFn, .maskAlternate]).isEmpty else { return false }
          guard
            !modifiers.contains(.maskCommand) || (keyEventState.isCompletionExpandable &&
              !keyEventState.multiLineDisplayModeIsAlwaysShown)
          else {
            // Only allow Tab key handling if Command is not pressed, or if it is used to expand the completion
            return false
          }
          // Dispatch side effect to main actor asynchronously
          Task { @MainActor in self?.handleTabKeyPressed() }
          return true
        })))

    // Initialize Escape key handler (triggered on key up - when press is completed)
    // NOTE: Callbacks run on CGEvent thread - use keyEventState for thread-safe state checks
    escapeKeyHandler = KeyEventHandler(
      manager: keyEventHandlerManager,
      configuration: .escape(),
      callbacks: .init(
        onKeyDown: { [keyEventState] isDoubleTap, _ in
          guard keyEventState.hasEditorState else { return false }
          if isDoubleTap {
            return true
          }
          guard !keyEventState.isAutomaticCompletionEnabled || keyEventState.hasCompletion else {
            return false
          }
          return true
        },
        onKeyUp: { [weak self, keyEventState] (isDoubleTap: Bool, _: CGEventFlags) in
          guard keyEventState.hasEditorState else { return false }
          if isDoubleTap {
            // Dispatch side effect to main actor asynchronously
            Task { @MainActor in self?.handleEscapeDoubleTap() }
            return true
          }
          guard !keyEventState.isAutomaticCompletionEnabled || keyEventState.hasCompletion else {
            return false
          }
          // Dispatch side effect to main actor asynchronously
          Task { @MainActor in self?.handleEscape() }
          return true
        }))

    // Initialize Command key handlers (triggered on both key down and key up)
    // Left Command key code is 55, Right Command key code is 54
    // NOTE: Callbacks run on CGEvent thread - use keyEventState for thread-safe state checks
    for code in [54, 55] {
      completionKeyHandlers.append(KeyEventHandler(
        manager: keyEventHandlerManager,
        configuration: .key(code),
        callbacks: .init(
          onKeyDown: { [weak self, keyEventState] _, _ in
            guard
              keyEventState.hasEditorState,
              keyEventState.isCompletionExpandable,
              !keyEventState.multiLineDisplayModeIsAlwaysShown
            else { return false }
            // Dispatch side effect to main actor asynchronously
            Task { @MainActor in self?.handleCommandKeyDown() }
            return true
          },
          onKeyUp: { [weak self, keyEventState] (_: Bool, _: CGEventFlags) in
            guard
              keyEventState.hasEditorState,
              keyEventState.isCompletionExpandable,
              !keyEventState.multiLineDisplayModeIsAlwaysShown
            else { return false }
            // Dispatch side effect to main actor asynchronously
            Task { @MainActor in self?.handleCommandKeyUp() }
            return true
          })))
    }
  }
}
