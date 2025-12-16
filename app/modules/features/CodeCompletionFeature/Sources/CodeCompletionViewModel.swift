// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import AppKit
import CodeCompletionFoundation
import CodeCompletionServiceInterface
import Combine
import Dependencies
import FileDiffFoundation
import FileDiffTypesFoundation
import KeyboardShortcutServiceInterface
import LoggingServiceInterface
import Observation
import SettingsServiceInterface
import ShellServiceInterface
import ThreadSafe
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
    self.appsActivationState = appsActivationState
    @Dependency(\.codeCompletionService) var codeCompletionService
    self.codeCompletionService = codeCompletionService
    @Dependency(\.keyboardShortcutService) var keyboardShortcutService
    self.keyboardShortcutService = keyboardShortcutService
    @Dependency(\.shellService) var shellService
    self.shellService = shellService
    themeController = XcodeThemeController {
      try await shellService
        .runAndThrow("xcode-select --print-path | awk -F\".app\" '{ print $1 }' | tr -d '\\n' | cat  - <(echo \".app\")") ?? "/Applications/Xcode.app"
    }

    // Create the key event handler manager
    keyEventHandlerManager = KeyEventHandlerManager(appsActivationState: appsActivationState)

    isEnabled = codeCompletionService.isAvailable.value
    if isEnabled {
      enable()
    }
    // Load Xcode theme font name
    Task {
      await loadXcodeTheme()
    }
    setUpKeyInterception()

    // Observe app activation state to start/stop key monitoring
    appsActivationState.sink { @Sendable state in
      Task { @MainActor [weak self] in
        guard let self else { return }
        if !state.isXcodeActive {
          editorState = nil
          completionTask = nil
          completion = nil
          cachedRequestId = nil
        }
        updateCompletionKeyHandlers()
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
    for completionKeyHandler in completionKeyHandlers { completionKeyHandler.stop() }

    xcodeObservation = xcodeObserver.statePublisher.sink { @Sendable state in
      Task { @MainActor [weak self] in
        await self?.handleXcodeStateChange(state)
      }
    }
  }

  /// Indicates if code completion is enabled (i.e. service is available)
  private(set) var isEnabled: Bool

  /// The leading offset between the editor and the text area frames.
  var leadingContentOffset: CGFloat = 0
  /// The trailing offset between the editor and the text area frames.
  var trailingContentOffset: CGFloat = 0
  var lineHeight: CGFloat?
  private(set) var xcodeBackgroundColor: NSColor?
  private(set) var xcodeCurrentLineColor: NSColor?
  /// The Xcode theme used for syntax highlighting.
  private(set) var xcodeTheme: XcodeTheme?
  /// The color space used by the window where the view is rendered.
  var colorSpace = NSColorSpace.sRGB

  private(set) var completionTask: CompletionTask?

  /// Calculate font height from font metrics (ascender + descender)
  var fontHeight: CGFloat = 12
  var font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
  var fontSize: CGFloat = 12

  private(set) var screenshot: CGImage?

  private(set) var isCompletionExpanded = false
  private(set) var showAutomaticCompletionStatusMessage = false
  /// Indicates whether to show the chat tooltip.
  private(set) var showChatTooltip = false

  @ObservationIgnored private(set) var styledCompletionTask: Task<Void, Error>?
  private(set) var styledCompletion: SyntaxHighlightedCompletion?

  let keyEventHandlerManager: KeyEventHandlerManager
  var completionKeyHandlers = [KeyEventHandler]()
  var escapeKeyHandler: KeyEventHandler?
  /// Thread-safe state for CGEvent callbacks to check without blocking on main actor
  let keyEventState = KeyEventState()

  /// The display string for the "show chat" keyboard shortcut.
  var showChatShortcutDisplay: String {
    "\(settingsService.value(for: \.keyboardShortcuts)[withDefault: .addContextToCurrentChat].display) to chat"
  }

  private(set) var isAutomaticCompletionEnabled = true {
    didSet {
      // Update thread-safe state for CGEvent callbacks
      keyEventState.update(isAutomaticCompletionEnabled: isAutomaticCompletionEnabled)
    }
  }

  /// The line number that needs vertical offset adjustment (either to show tooltip or completion).
  var lineThatNeedsVerticalOffset: Int? {
    didSet {
      if lineThatNeedsVerticalOffset != oldValue {
        verticalContentOffset = nil
      }
    }
  }

  /// The offset between the top of the view and the top of the text being completed.
  var verticalContentOffset: CGFloat? = nil {
    didSet {
      if verticalContentOffset != oldValue {
        if completion != nil {
          screenShotEditorIfNeeded()
        } else if showChatTooltip, oldValue != nil {
          // When changed, hide the tooltip instead of showing having a jaggy scrolling
          chatTooltipTask?.cancel()
          showChatTooltip = false
          updateChatTooltipVisibility() // Reset a timer to show the tooltip
        }
      }
    }
  }

  private(set) var completion: CompletionSuggestion? {
    didSet {
      // Update thread-safe state for CGEvent callbacks
      keyEventState.update(
        hasCompletion: completion != nil,
        isCompletionExpandable: completion?.diff.count ?? 0 > 1,
        multiLineDisplayModeIsAlwaysShown: settingsService.value(for: \.multiLineCodeCompletionDisplayMode).isAlwaysShown)

      updateCompletionKeyHandlers()

      if let completion {
        needsLayout()
        screenShotEditorIfNeeded()
        styledCompletionTask?.cancel()
        styledCompletionTask = Task {
          let styledCompletion = await CompletionSyntaxHighlighter.highlight(completion, xcodeTheme: xcodeTheme)
          try Task.checkCancellation()
          self.styledCompletion = styledCompletion
        }

        // Hide chat tooltip when completion appears, but don't restart the delay
        // (the delay is managed by editorState changes)
        chatTooltipTask?.cancel()
        showChatTooltip = false
        lineThatNeedsVerticalOffset = completionTask?.request.selection.start.line
      } else {
        styledCompletionTask?.cancel()
        styledCompletion = nil
        lineThatNeedsVerticalOffset = nil
        updateChatTooltipVisibility()
      }
    }
  }

  /// Determines if the completion should be expandable (i.e., requires Command key to show fully).
  var isCompletionExpandable: Bool {
    completion?.diff.count ?? 0 > 1
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

  func handleTabKeyPressed() {
    guard let completion else { return }
    Task {
      await apply(completion: completion)
    }
  }

  func apply(completion: CompletionSuggestion) async {
    guard let editorState else { return }

    // Convert completion suggestion to FileChange and apply using XcodeController
    do {
      // Convert CompletionSuggestion.LineChange to FileChange.LineChange
      let lineByLineChange = try FileDiff.getFileChange(changing: editorState.content, to: completion.newContent)
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

      // Immediately update editor state to new content.
      let sel = completion.newCursorSelection
      self.editorState = .init(
        workspaceURL: editorState.workspaceURL,
        fileURL: editorState.fileURL,
        content: fileChange.suggestedNewContent,
        selection: CursorRange(
          start: CursorPosition(line: sel.start.line, character: sel.start.character),
          end: CursorPosition(line: sel.end.line, character: sel.end.character)))

      self.completion = nil
      cachedRequestId = nil
    } catch {
      defaultLogger.error("Failed to apply code completion", error)
      self.completion = nil
      cachedRequestId = nil
    }
  }

  func handleEscape() {
    if completion != nil {
      completion = nil
      cachedRequestId = nil
      if let cachedRequestId {
        codeCompletionService.deleteCachedCompletion(cachedRequestId: cachedRequestId)
      }
    } else if !isAutomaticCompletionEnabled {
      fetchCompletion()
    }
  }

  func handleEscapeDoubleTap() {
    isAutomaticCompletionEnabled.toggle()
    // Show a message that the status was changed.
    statusMessageTask?.cancel()
    showAutomaticCompletionStatusMessage = true
    statusMessageTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 5_000_000_000)
      guard !Task.isCancelled else { return }
      self?.showAutomaticCompletionStatusMessage = false
    }
  }

  func handleOptionKeyDown() {
    isCompletionExpanded = true
  }

  func handleOptionKeyUp() {
    isCompletionExpanded = false
  }

  func handleNextWordAcceptance() {
    guard let editorState else { return }
    let position = editorState.selection.start
    guard
      let nextWordCompletion = completion?.completionWithNextWord(from: .init(
        line: position.line,
        character: position.character))
    else { return }
    Task {
      await apply(completion: nextWordCompletion.newCompletion)
      completion = nextWordCompletion.remainingCompletion
    }
  }

  private var cachedRequestId: Int?

  private let needsLayout: () -> Void
  private let screenshotEditor: () async throws -> CGImage?
  /// Font name from Xcode theme
  private var xcodeThemeFontName: String?

  private var cancellables = Set<AnyCancellable>()
  private let settingsService: SettingsService
  private let xcodeObserver: XcodeObserver
  private let xcodeController: XcodeController
  private let codeCompletionService: CodeCompletionService
  private let appsActivationState: ReadonlyCurrentValueSubject<AppsActivationState>
  private let shellService: ShellService
  private let keyboardShortcutService: KeyboardShortcutService
  private let themeController: XcodeThemeController
  private var xcodeObservation: AnyCancellable?

  private var statusMessageTask: Task<Void, Never>?
  private var chatTooltipTask: Task<Void, Error>?

  private var editorState: EditorState? {
    didSet {
      keyEventState.update(hasEditorState: editorState != nil)
      updateChatTooltipVisibility()
    }
  }

  private var isXcodeActive: Bool {
    appsActivationState.value.isXcodeActive
  }

  /// Activate  / deactivate the completion key handler.
  /// This should be called when there is a change to Xcode's active state, or to the completion.
  private func updateCompletionKeyHandlers() {
    if appsActivationState.value.isXcodeActive, completion != nil {
      for completionKeyHandler in completionKeyHandlers { completionKeyHandler.start() }
    } else {
      for completionKeyHandler in completionKeyHandlers { completionKeyHandler.stop() }
    }
  }

  /// Updates the chat tooltip visibility based on the current editor state.
  /// Shows the tooltip after a 1-second delay when there's an editor state but no completion.
  private func updateChatTooltipVisibility() {
    guard let editorState else { return }
    guard completion == nil else {
      showChatTooltip = false
      return
    }
    if editorState.selection.start.line == lineThatNeedsVerticalOffset, chatTooltipTask != nil {
      // Cursor line not changed and tooltip task already running
      return
    }
    chatTooltipTask?.cancel()
    showChatTooltip = false
    lineThatNeedsVerticalOffset = editorState.selection.start.line

    // Show tooltip after 1 second delay
    let file = editorState.fileURL
    let workspace = editorState.workspaceURL
    chatTooltipTask = Task { [weak self] in
      try await Task.sleep(nanoseconds: 1_000_000_000)
      try Task.checkCancellation()
      guard
        let self,
        self.editorState?.fileURL == file,
        self.editorState?.workspaceURL == workspace,
        completion == nil
      else { return }
      showChatTooltip = true
    }
  }

  private func enable() {
    isEnabled = true
    escapeKeyHandler?.start()
  }

  private func handleXcodeStateChange(_ state: AXState<XcodeState>) async {
    guard isXcodeActive else {
      completionTask = nil
      completion = nil
      cachedRequestId = nil
      screenshot = nil
      editorState = nil
      defaultLogger.log("Not requesting completion: Xcode is not active")
      return
    }

    guard let workspace = state.focusedWorkspace else {
      completionTask = nil
      completion = nil
      cachedRequestId = nil
      screenshot = nil
      editorState = nil
      defaultLogger.log("Not requesting completion: no focused workspace")
      return
    }

    let focussedFile: URL? =
      if let file = workspace.tabs.first(where: { $0.isFocused })?.knownPath {
        file
      } else {
        await xcodeObserver.focusedTabURL(in: workspace)
      }
    guard let focussedFile else {
      completionTask = nil
      completion = nil
      cachedRequestId = nil
      screenshot = nil
      editorState = nil
      defaultLogger.log("Not requesting completion: no focused file")
      return
    }

    guard let editor = workspace.focussedEditor else {
      completionTask = nil
      completion = nil
      cachedRequestId = nil
      screenshot = nil
      editorState = nil
      defaultLogger.log("Not requesting completion: no focused editor")
      return
    }

    guard let tab = workspace.tabs.first(where: { $0.isFocused && $0.fileName == focussedFile.lastPathComponent }) else {
      completionTask = nil
      completion = nil
      cachedRequestId = nil
      screenshot = nil
      editorState = nil
      defaultLogger
        .log(
          "Not requesting completion: no matching tab. Focussed file: \(focussedFile.lastPathComponent). Tabs: \(workspace.tabs.map { "\($0.fileName) is focused: \($0.isFocused)" }.joined(separator: "|"))")
      return
    }

    guard let content = tab.lastKnownContent else {
      completionTask = nil
      completion = nil
      cachedRequestId = nil
      screenshot = nil
      editorState = nil
      defaultLogger.log("Not requesting completion: no tab content")
      return
    }

    let selections = editor.selections
    guard selections.count == 1, let selection = selections.first else {
      completionTask = nil
      completion = nil
      cachedRequestId = nil
      screenshot = nil
      defaultLogger.log("Not requesting completion due to missing selection")
      return
    }

    let editorState = EditorState(
      workspaceURL: workspace.url,
      fileURL: focussedFile,
      content: content,
      selection: selection)

    if editorState == self.editorState {
      // No changes, skip
      defaultLogger.log("Not requesting completion unchanged editor state")
      return
    }

    self.editorState = editorState
    completion = nil
    cachedRequestId = nil
    screenshot = nil
    completionTask = nil
    guard isAutomaticCompletionEnabled else { return }

    fetchCompletion()
  }

  private func fetchCompletion() {
    guard let editorState else { return }
    let selection = editorState.selection
    let completionRequest = CompletionRequest(
      workspace: editorState.workspaceURL,
      file: editorState.fileURL,
      content: editorState.content,
      selection: .init(
        start: .init(line: selection.start.line, character: selection.start.character),
        end: .init(line: selection.end.line, character: selection.end.character)),
      timeout: 1)
    let taskId = UUID()

    if let (cacheId, cachedCompletion) = try? codeCompletionService.cachedCompletion(completionRequest) {
      defaultLogger.log("Using cached completion \(cachedCompletion?.diff.debugDescription ?? "nil")")
      completion = cachedCompletion
      cachedRequestId = cacheId
      completionTask = CompletionTask(
        id: taskId,
        request: .init(fileURL: editorState.fileURL, content: editorState.content, selection: selection))
    } else {
      let task = Task { [weak self] in
        do {
          let debounceMs = self?.settingsService.value(for: \.codeCompletionDebounceMs) ?? 250
          try await Task.sleep(nanoseconds: UInt64(debounceMs) * 1_000_000)
          try Task.checkCancellation()
          guard let self, completionTask?.id == taskId else {
            return
          }
          let result = try await codeCompletionService.suggestCompletion(completionRequest)
          try Task.checkCancellation()
          guard completionTask?.id == taskId else {
            return
          }
          completion = result?.suggestion
          cachedRequestId = result?.cachedRequestId
          isCompletionExpanded = settingsService.value(for: \.multiLineCodeCompletionDisplayMode).isAlwaysShown
        } catch {
          throw error
        }
      }
      let cancellable = AnyCancellable { task.cancel() }
      completionTask = CompletionTask(
        task: task,
        id: taskId,
        request: .init(fileURL: editorState.fileURL, content: editorState.content, selection: selection)) { cancellable.cancel() }
    }
  }

  private func disable() {
    isEnabled = false
    completion = nil
    cachedRequestId = nil
    escapeKeyHandler?.stop()
    for completionKeyHandler in completionKeyHandlers { completionKeyHandler.stop() }
  }

  // MARK: - Screenshot Management

  /// When screenshoting is enabled to display multiline diff, screenshot the editor if we need a screenshot
  private func screenShotEditorIfNeeded() {
    guard settingsService.value(for: \.multiLineCodeCompletionDisplayMode).usesScreenshotToAddSpace else {
      return
    }
    guard isCompletionExpandable, let completionId = completionTask?.id else {
      return
    }

    Task {
      let screenshot = try await screenshotEditor()
      if completionTask?.id == completionId {
        self.screenshot = screenshot
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
    xcodeTheme = theme
    xcodeThemeFontName = theme.plainTextFont.name
    xcodeBackgroundColor = theme.backgroundColor?.nsColor(windowColorSpace: colorSpace)
    xcodeCurrentLineColor = theme.currentLineColor?.nsColor(windowColorSpace: colorSpace)
  }

}

// MARK: - EditorState

private struct EditorState: Sendable, Equatable {
  let workspaceURL: URL
  let fileURL: URL
  let content: String
  let selection: CursorRange
}

// MARK: - CompletionTask

struct CompletionTask {
  let task: Task<Void, Error>?
  let id: UUID
  let request: CompletionRequest
  let cleanup: (() -> Void)?

  init(task: Task<Void, Error>? = nil, id: UUID, request: CompletionRequest, cleanup: (() -> Void)? = nil) {
    self.task = task
    self.id = id
    self.request = request
    self.cleanup = cleanup
  }

  struct CompletionRequest {
    let fileURL: URL
    let content: String
    let selection: CursorRange
  }
}

extension MultiLineCodeCompletionDisplayMode {
  var isAlwaysShown: Bool {
    self == .expandCompletionAddingSpaceInExistingCode || self == .expandCompletionOverExistingCode
  }

  var usesScreenshotToAddSpace: Bool {
    self == .expandCompletionAddingSpaceInExistingCode || self == .expandCompletionAddingSpaceInExistingCodeWhenTriggered
  }
}
