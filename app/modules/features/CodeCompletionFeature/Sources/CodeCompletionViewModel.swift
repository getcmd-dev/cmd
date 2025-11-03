// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import CodeCompletionFeatureInterface
import CodeCompletionFoundation
import CodeCompletionServiceInterface
import Combine
import Dependencies
import Observation
import SettingsServiceInterface
import XcodeObserverServiceInterface

// MARK: - CodeCompletionViewModel

@Observable @MainActor
final class CodeCompletionViewModel {
  init() {
    @Dependency(\.settingsService) var settingsService
    self.settingsService = settingsService
    @Dependency(\.xcodeObserver) var xcodeObserver
    self.xcodeObserver = xcodeObserver
    @Dependency(\.appsActivationState) var appsActivationState
    @Dependency(\.codeCompletionService) var codeCompletionService
    self.codeCompletionService = codeCompletionService

    isEnabled = settingsService.value(for: \.enableCodeCompletion)
    if isEnabled {
      enable()
    }

    settingsService.liveValue(for: \.enableCodeCompletion).sink { @Sendable value in
      Task { @MainActor [weak self] in
        if value {
          self?.enable()
        } else {
          self?.disable()
        }
      }
    }.store(in: &cancellables)

    // Observe app activation state to start/stop modifier key monitoring
    appsActivationState.sink { @Sendable [weak self] state in
      Task { @MainActor in
        self?.appActivationState = state
        self?.handleAppActivationChange(state)
      }
    }.store(in: &cancellables)
  }

  private(set) var isEnabled: Bool

  private(set) var completion: CompletionSuggestion?

  @ObservationIgnored private var appActivationState: AppsActivationState?

  private var cancellables = Set<AnyCancellable>()
  private let settingsService: SettingsService
  private let xcodeObserver: XcodeObserver
  private let codeCompletionService: CodeCompletionService
  private var xcodeObservation: AnyCancellable?
  private var modifierEventMonitor: Any?
  private var tabKeyMonitor: Any?

  private var editorState: EditorState?

  private var completionTask: CompletionTask?

  private func enable() {
    isEnabled = true
    xcodeObservation = xcodeObserver.statePublisher.sink { @Sendable state in
      Task { @MainActor [weak self] in
        await self?.handleXcodeStateChange(state)
      }
    }
  }

  private func handleXcodeStateChange(_ state: AXState<XcodeState>) async {
    guard
      let workspace = state.focusedWorkspace,
      let focussedFile = await xcodeObserver.focusedTabURL(in: workspace),
      let editor = workspace.editors.first(where: { $0.isFocused }),
      let tab = workspace.tabs.first(where: { $0.isFocused && $0.fileName == focussedFile.lastPathComponent }),
      let content = tab.lastKnownContent
    else {
      completionTask = nil
      completion = nil
      return
    }
    let selections = editor.selections
    guard selections.count == 1, let selection = selections.first else {
      completionTask = nil
      completion = nil
      return
    }

    let editorState = EditorState(
      fileURL: focussedFile,
      content: content,
      selection: selection)
    if editorState != self.editorState {
      self.editorState = editorState
      let taskId = UUID()
      let task = Task { [weak self] in
        try await Task.sleep(nanoseconds: 250_000_000) // 250ms debounce
        try Task.checkCancellation() // TODO: check if this work (We have fallbacks)
        guard let self, completionTask?.id == taskId else { return }
        let completion = try await codeCompletionService.suggestCompletion(
          workspace: workspace.url,
          file: focussedFile,
          content: content,
          selection: .init(
            start: .init(line: selection.start.line, character: selection.start.character),
            end: .init(line: selection.end.line, character: selection.end.character)),
          timeout: 1)
        self.completion = completion
      }
      let cancellable = AnyCancellable { task.cancel() }
      completionTask = CompletionTask(task: task, id: taskId) { cancellable.cancel() }
    }
  }

  private func disable() {
    isEnabled = false
    stopModifierMonitoring()
  }

  // MARK: - App Activation Monitoring

  private func handleAppActivationChange(_ state: AppsActivationState) {
    if state.isEitherXcodeOrHostAppActive {
      startModifierMonitoring()
    } else {
      stopModifierMonitoring()
    }
  }

  // MARK: - Modifier Key Monitoring

  private func startModifierMonitoring() {
    guard isEnabled else { return }
    guard modifierEventMonitor == nil else { return }

    modifierEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
      Task { @MainActor in
        self?.handleModifierEvent(event)
      }
    }

    tabKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
      Task { @MainActor in
        guard event.keyCode == 48 else { return } // tab
        guard self?.appActivationState?.isXcodeActive == true else { return }
        self?.handleTabKeyPressed()
      }
    }
  }

  private func stopModifierMonitoring() {
    if let monitor = modifierEventMonitor {
      NSEvent.removeMonitor(monitor)
      modifierEventMonitor = nil
    }
    if let monitor = tabKeyMonitor {
      NSEvent.removeMonitor(monitor)
      tabKeyMonitor = nil
    }
  }

  private func handleModifierEvent(_ event: NSEvent) {
    if event.modifierFlags.contains(.command) {
      expandCodeCompletion()
    } else {
      collapseCodeCompletion()
    }
  }

  private func handleTabKeyPressed() {
    guard let completion else { return }

    let pasteboard = NSPasteboard.general
    let previousContent = pasteboard.string(forType: .string)

    pasteboard.clearContents()
    pasteboard.setString(completion.completion, forType: .string)

    let vKey: CGKeyCode = 9
    let cmdFlag = CGEventFlags.maskCommand

    if let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: vKey, keyDown: true) {
      keyDownEvent.flags = cmdFlag
      keyDownEvent.post(tap: .cghidEventTap)
    }

    if let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: vKey, keyDown: false) {
      keyUpEvent.flags = cmdFlag
      keyUpEvent.post(tap: .cghidEventTap)
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      if let previousContent {
        pasteboard.clearContents()
        pasteboard.setString(previousContent, forType: .string)
      }
    }

    self.completion = nil
  }

  // MARK: - Code Completion Actions

  private func expandCodeCompletion() {
    // TODO: Implement expansion logic
  }

  private func collapseCodeCompletion() {
    // TODO: Implement collapse logic
  }

}

// MARK: - EditorState

private struct EditorState: Sendable, Equatable {
  let fileURL: URL
  let content: String
  let selection: CursorRange
}

// MARK: - CompletionTask

private struct CompletionTask {
  let task: Task<Void, Error>
  let id: UUID
  let cleanup: () -> Void
}
