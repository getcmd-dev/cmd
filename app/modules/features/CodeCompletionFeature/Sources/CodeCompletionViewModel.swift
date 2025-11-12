// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import AppKit
import CodeCompletionFoundation
import CodeCompletionServiceInterface
import Combine
import Dependencies
import FileDiffFoundation
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
  init(
    needsLayout: @escaping @MainActor () -> Void,
    screenshotEditor: @escaping @MainActor () async throws -> CGImage?)
  {
    self.needsLayout = needsLayout
    self.screenshotEditor = screenshotEditor
    @Dependency(\.settingsService) var settingsService
    self.settingsService = settingsService
    @Dependency(\.xcodeObserver) var xcodeObserver
    self.xcodeObserver = xcodeObserver
    @Dependency(\.xcodeController) var xcodeController
    self.xcodeController = xcodeController
    @Dependency(\.appsActivationState) var appsActivationState
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

    isEnabled = codeCompletionService.isAvailable.currentValue
    if isEnabled {
      enable()
    }

    // Load Xcode theme font name
    Task {
      await loadXcodeTheme()
    }

    // Initialize Tab key handler
    tabKeyHandler = TabKeyHandler(
      acceptSuggestion: { [weak self] in
        self?.handleTabKeyPressed()
      },
      shouldAccept: { [weak self] in
        guard let self else { return false }
        // Check if we have an active completion and Xcode is focused
        return completion != nil
      })

    // Observe app activation state to start/stop modifier key monitoring
    appsActivationState.sink { @Sendable state in
      Task { @MainActor [weak self] in
        guard let self else { return }
        if state.isXcodeActive, completion != nil {
          tabKeyHandler?.start()
        } else {
          tabKeyHandler?.stop()
        }
      }
    }.store(in: &cancellables)

    codeCompletionService.isAvailable.sink { @Sendable isAvailable in
      Task { @MainActor [weak self] in
        self?.isEnabled = isAvailable
        if isAvailable {
          self?.enable()
        } else {
          self?.disable()
        }
      }
    }.store(in: &cancellables)
  }

  /// Indicates if code completion is enabled (i.e. service is available)
  private(set) var isEnabled: Bool

  /// The offset between the left of the view and the left of the text being completed.
  var horizontalContentOffset: CGFloat = 0
  var lineHeight: CGFloat?
  private(set) var xcodeBackgroundColor: NSColor?
  private(set) var xcodeCurrentLineColor: NSColor?
  /// The color space used by the window where the view is rendered.
  var colorSpace = NSColorSpace.sRGB

  private(set) var completionTask: CompletionTask?

  /// Calculate font height from font metrics (ascender + descender)
  var fontHeight: CGFloat = 12
  var font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
  var fontSize: CGFloat = 12

  private(set) var screenshot: CGImage?

  /// The offset between the top of the view and the top of the text being completed.
  var verticalContentOffset: CGFloat = 0 {
    didSet {
      // If we have a screenshot and scrolled up (offset became smaller), request a new screenshot
      if
        screenshot != nil,
        let screenshotOffset = screenshotVerticalOffset,
        verticalContentOffset < screenshotOffset
      {
        screenShotEditorIfNeeded()
      }
    }
  }

  private(set) var completion: CodeCompletionServiceInterface.CompletionSuggestion? {
    didSet {
      if completion == nil {
        tabKeyHandler?.stop()
      } else {
        needsLayout()
        screenShotEditorIfNeeded()
        tabKeyHandler?.start()
      }
    }
  }

  /// Calculate line spacing to match Xcode's line height
  var lineSpacing: CGFloat {
    guard let lineHeight, lineHeight > 0 else { return 0 }
    return lineHeight - fontHeight
  }

  /// Called when the font size needs to be updated.
  func updateFont(toMatch lineWidth: CGFloat, for content: String) {
    let fontName = xcodeThemeFontName ?? "SFMono-Regular"

    // Derive font size from line height
    fontSize = NSFont.size(matching: lineWidth, for: content, using: fontName)
    font = NSFont.createFont(name: fontName, size: fontSize)
    fontHeight = font.size(for: content).height
  }

  /// The vertical offset at which the screenshot was taken
  private var screenshotVerticalOffset: CGFloat?

  private let needsLayout: () -> Void
  private let screenshotEditor: () async throws -> CGImage?
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
  private var tabKeyHandler: TabKeyHandler?

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
      screenshot = nil
      screenshotVerticalOffset = nil
      defaultLogger.log("Not requesting completion due to missing content/tab etc")
      return
    }

    let selections = editor.selections
    guard selections.count == 1, let selection = selections.first else {
      completionTask = nil
      completion = nil
      screenshot = nil
      screenshotVerticalOffset = nil
      defaultLogger.log("Not requesting completion due to missing selection")
      return
    }

    let editorState = EditorState(
      fileURL: focussedFile,
      content: content,
      selection: selection)

    if editorState == self.editorState {
      // No changes, skip
      defaultLogger.log("Not requesting completion unchanged editor state")
      return
    }

    self.editorState = editorState
    let taskId = UUID()
    let task = Task { [weak self] in
      let debounceMs = self?.settingsService.value(for: \.codeCompletionDebounceMs) ?? 250
      try await Task.sleep(nanoseconds: UInt64(debounceMs) * 1_000_000)
      try Task.checkCancellation() // TODO: check if this work (We have fallbacks)
      guard let self, completionTask?.id == taskId else {
        return
      }
      defaultLogger.log("Requesting completion")
      let completion = try await codeCompletionService.suggestCompletion(
        workspace: workspace.url,
        file: focussedFile,
        content: content,
        selection: .init(
          start: .init(line: selection.start.line, character: selection.start.character),
          end: .init(line: selection.end.line, character: selection.end.character)),
        timeout: 1)
      defaultLogger.log("Got completion response. Has suggestions? \(completion != nil)")
      self.completion = completion
    }
    completion = nil
    screenshot = nil
    screenshotVerticalOffset = nil
    let cancellable = AnyCancellable { task.cancel() }
    completionTask = CompletionTask(
      task: task,
      id: taskId,
      request: .init(fileURL: focussedFile, content: content, selection: selection)) { cancellable.cancel() }
  }

  private func disable() {
    isEnabled = false
    completion = nil
    tabKeyHandler?.stop()
  }

  private func handleTabKeyPressed() {
    guard let completion, let completionTask, let editorState else { return }

    // Convert completion suggestion to FileChange and apply using XcodeController
    Task {
      do {
        // Convert CompletionSuggestion.LineChange to FileChange.LineChange
        let lineByLineChange = try FileDiff.getFileChange(changing: completionTask.request.content, to: completion.newContent)
          .diff

        let fileChange = FileChange(
          filePath: completion.file,
          oldContent: editorState.content,
          suggestedNewContent: completion.newContent,
          selectedChange: lineByLineChange,
          newSelections: [.init(
            start: .init(line: completion.newCursorSelection.start.line, column: completion.newCursorSelection.start.character),
            end: .init(line: completion.newCursorSelection.end.line, column: completion.newCursorSelection.end.character))])

        try await xcodeController.apply(fileChange: fileChange, editMode: .xcodeExtension)
        self.completion = nil
      } catch {
        defaultLogger.error("Failed to apply code completion", error)
        self.completion = nil
      }
    }
  }

  // MARK: - Screenshot Management

  /// When screenshoting is enabled to display multiline diff, screenshot the editor if we need a screenshot
  private func screenShotEditorIfNeeded() {
    let multiLineCodeCompletionDisplayMode: MultiLineCodeCompletionDisplayMode = settingsService
      .value(for: \.multiLineCodeCompletionDisplayMode)
    guard
      multiLineCodeCompletionDisplayMode == .expandCompletionAddingSpaceInExistingCode || multiLineCodeCompletionDisplayMode ==
      .expandCompletionAddingSpaceInExistingCodeWhenTriggered
    else {
      return
    }
    guard completion?.diff.count ?? 0 > 1, let completionId = completionTask?.id else {
      return
    }

    Task {
      let screenshot = try await screenshotEditor()
      if completionTask?.id == completionId {
        self.screenshot = screenshot
        self.screenshotVerticalOffset = self.verticalContentOffset
      }
    }
  }

  // MARK: - Theme Font Loading

  private func loadXcodeTheme() async {
    let isDarkMode = NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    guard let theme = await themeController.getCurrentTheme(isDarkMode: isDarkMode) else {
      xcodeThemeFontName = "SFMono-Medium"
      return
    }
    xcodeThemeFontName = theme.plainTextFont.name
    xcodeBackgroundColor = theme.backgroundColor?.nsColor(windowColorSpace: colorSpace)
    xcodeCurrentLineColor = theme.currentLineColor?.nsColor(windowColorSpace: colorSpace)
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
    let fileURL: URL
    let content: String
    let selection: CursorRange
  }
}
