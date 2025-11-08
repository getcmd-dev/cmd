// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import CodeCompletionFoundation
import CodeCompletionServiceInterface
import Combine
import Dependencies
import KeyboardShortcutServiceInterface
import LoggingServiceInterface
import Observation
import SettingsServiceInterface
import ShellServiceInterface
import XcodeControllerServiceInterface
import XcodeObserverServiceInterface
import XcodeThemeFoundation

// MARK: - CodeCompletionViewModel

@Observable @MainActor
final class CodeCompletionViewModel {
  init() {
    @Dependency(\.settingsService) var settingsService
    self.settingsService = settingsService
    @Dependency(\.xcodeObserver) var xcodeObserver
    self.xcodeObserver = xcodeObserver
    @Dependency(\.xcodeController) var xcodeController
    self.xcodeController = xcodeController
//    @Dependency(\.appsActivationState) var appsActivationState
    @Dependency(\.codeCompletionService) var codeCompletionService
    self.codeCompletionService = codeCompletionService
    @Dependency(\.keyboardShortcutService) var keyboardShortcutService
    self.keyboardShortcutService = keyboardShortcutService
    @Dependency(\.shellService) var shellService
    self.shellService = shellService
    themeController = XcodeThemeController {
      try await shellService
        .runAndThrows("xcode-select --print-path | awk -F\".app\" '{ print $1 }' | tr -d '\\n' | cat  - <(echo \".app\")") ?? "/Applications/Xcode.app"
    }

    isEnabled = settingsService.value(for: \.enableCodeCompletion)
    if isEnabled {
      enable()
    }

    // Load Xcode theme font name
    Task {
      await loadXcodeThemeFont()
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

//    // Observe app activation state to start/stop modifier key monitoring
//    appsActivationState.sink { @Sendable [weak self] state in
//      Task { @MainActor in
//        self?.appActivationState = state
//        self?.handleAppActivationChange(state)
//      }
//    }.store(in: &cancellables)
  }

  private(set) var isEnabled: Bool

  var verticalContentOffset: CGFloat = 0
  var horizontalContentOffset: CGFloat = 0
  var lineHeight: CGFloat?
  var escapeKeyPressObservation: AnyCancellable?

  private(set) var completionTask: CompletionTask?

  /// Calculate font height from font metrics (ascender + descender)
  var fontHeight: CGFloat = 12
  var font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
  var fontSize: CGFloat = 12

  private(set) var completion: CodeCompletionServiceInterface.CompletionSuggestion? {
    didSet {
      if completion == nil {
//        print("clearing tab listnere")
//        escapeKeyPressObservation = nil
      } else {
        print("adding tab listnere")
        escapeKeyPressObservation = keyboardShortcutService.registerShortcut(
          name: "Code completion",
          .tab,
          modifiers: [],
          activationCondition: .xcodeActive)
        {
            
          print("got tab callback")
          Task { @MainActor [weak self] in
            self?.handleTabKeyPressed()
          }
        }
      }
    }
  }

  /// Calculate line spacing to match Xcode's line height
  var lineSpacing: CGFloat {
    guard let lineHeight, lineHeight > 0 else { return 0 }
    return lineHeight - fontHeight
  }

  /// Font for code completion (derived from line height)
  /// Font for code completion (derived from line height)
  func updateFont(toMatch lineWidth: CGFloat, for content: String) {
    let fontName = xcodeThemeFontName ?? "SFMono-Regular"

    // Derive font size from line height
    fontSize = NSFont.size(matching: lineWidth, for: content, using: fontName)
    font = NSFont.createFont(name: fontName, size: fontSize)
    fontHeight = font.size(for: content).height
  }

  /// Font name from Xcode theme
  private var xcodeThemeFontName: String?

  private var cancellables = Set<AnyCancellable>()
  private let settingsService: SettingsService
  private let xcodeObserver: XcodeObserver
  private let xcodeController: XcodeController
  private let codeCompletionService: CodeCompletionService
  private let shellService: ShellService
  private let keyboardShortcutService: KeyboardShortcutService
  private let themeController: XcodeThemeController
  private var xcodeObservation: AnyCancellable?
  private var editorState: EditorState?

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
      let editor = workspace.focussedEditor,
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
        let debounceMs = self?.settingsService.value(for: \.codeCompletionDebounceMs) ?? 250
        try await Task.sleep(nanoseconds: UInt64(debounceMs) * 1_000_000)
        try Task.checkCancellation() // TODO: check if this work (We have fallbacks)
        guard let self, completionTask?.id == taskId else {
          return
        }
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
      completion = nil
      let cancellable = AnyCancellable { task.cancel() }
      completionTask = CompletionTask(
        task: task,
        id: taskId,
        request: .init(content: content, selection: selection)) { cancellable.cancel() }
    }
  }

  private func disable() {
    isEnabled = false
    completion = nil
//    stopModifierMonitoring()
  }

  private func handleTabKeyPressed() {
    guard let completion, let completionTask, let editorState else { return }

    // Convert completion suggestion to FileChange and apply using XcodeController
    Task {
      do {
        // Convert CompletionSuggestion.LineChange to FileChange.LineChange
        let oldContent = completionTask.request.content
        let replacementStart = completion.diffLineStart
        var change = [LineChange]()
        let oldLines = oldContent.split(separator: "\n", omittingEmptySubsequences: false)
        let numberOfReplacedLines = completion.diff.filter { $0.changes.contains(where: { $0.type != .added }) }.count
        guard replacementStart < oldLines.count else {
          defaultLogger.error("The completion start line \(replacementStart) exceeds the file size (oldLines.count)")
          self.completion = nil
          return
        }

        for i in 0..<replacementStart {
          change.append(.init(i, 0..<1, oldLines[i] + "\n", .unchanged))
        }
        for i in 0..<numberOfReplacedLines {
          change.append(.init(replacementStart + i, 0..<1, oldLines[replacementStart + i], .removed))
        }
        for (i, l) in completion.diff.filter({ $0.changes.contains(where: { $0.type != .removed }) }).enumerated() {
          let line = l.changes.filter({ $0.type != .removed }).map(\.text).joined()
          change.append(.init(replacementStart + i, 0..<1, line, .added))
        }
        for i in replacementStart + numberOfReplacedLines..<oldLines.count {
          change.append(.init(i + numberOfReplacedLines - 1, 0..<1, oldLines[i] + "\n", .unchanged))
        }

        for (i, l) in change.enumerated() {
          print("L\(i):\(l.type == .added ? "+" : (l.type == .removed ? "-" : " "))\(l.content)")
        }

        let fileChange = FileChange(
          filePath: completion.file,
          oldContent: editorState.content,
          suggestedNewContent: completion.newContent,
          selectedChange: change)

        try await xcodeController.apply(fileChange: fileChange, editMode: .xcodeExtension)
        self.completion = nil
      } catch {
        defaultLogger.error("Failed to apply code completion", error)
      }
    }
  }

  // MARK: - Theme Font Loading

  private func loadXcodeThemeFont() async {
    let font = await themeController.getCurrentThemeFont()
    xcodeThemeFontName = font.name
    print("Loaded Xcode theme font: \(font.name) - \(font.size)")
  }

}

// MARK: - EditorState

private struct EditorState: Sendable, Equatable {
  let fileURL: URL
  let content: String
  let selection: CursorRange
}

// MARK: - CompletionTask

struct CompletionTask {
  let task: Task<Void, Error>
  let id: UUID
  let request: CompletionRequest
  let cleanup: () -> Void

  struct CompletionRequest {
    let content: String
    let selection: CursorRange
  }
}
