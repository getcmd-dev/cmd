// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppKit
@preconcurrency import Combine
import ConcurrencyFoundation
import ThreadSafe
import XcodeObserverServiceInterface

// MARK: - SourceEditorObserver

@ThreadSafe
final class SourceEditorObserver: AXElementObserver, @unchecked Sendable {
  @MainActor
  init?(
    runningApplication: NSRunningApplication,
    editorElement: AXUIElement)
  {
    self.runningApplication = runningApplication
    self.editorElement = editorElement

    guard
      let fileName = editorElement.caching({
        $0.firstParent(where: { $0.identifier == "editor context" })
      }, cacheKey: "editor-context-parent")?.description
    else {
      logger.error("Failed to get file name from editor element")
      return nil
    }
    self.fileName = fileName
    internalState = .init(InternalXcodeEditorState(
      fileName: fileName,
      id: id,
      content: "",
      selections: [],
      compilerMessages: []))
    super.init(element: editorElement)

    updateContent()

    observeAXNotifications()
  }

  let id = UUID().uuidString

  let editorElement: AXUIElement

  var state: ReadonlyCurrentValueSubject<InternalXcodeEditorState, Never> {
    .init(internalState.value, publisher: internalState.eraseToAnyPublisher())
  }

  private let fileName: String

  private var axSubscription: AnyCancellable?

  private let internalState: CurrentValueSubject<InternalXcodeEditorState, Never>
  private let runningApplication: NSRunningApplication

  @MainActor
  private func observeAXNotifications() {
    guard
      let axNotificationPublisher = try? AXNotificationPublisher(
        app: runningApplication,
        element: editorElement,
        notificationNames:
        kAXSelectedTextChangedNotification,
        kAXValueChangedNotification)
    else {
      logger.error("Failed to create AXNotificationPublisher")
      return
    }

    axSubscription = axNotificationPublisher.sink { [weak self] notification in
      guard let self else { return }

      guard let event = AXNotification(rawValue: notification.name) else {
        return
      }

      switch event {
      case .valueChanged,
           .selectedTextChanged:
        updateContent()
      default: break
      }
    }
  }

  private func updateContent() {
    guard let content = editorElement.value else {
      logger.error("Failed to get content from editor element")
      return
    }
    let selectedTextRange = editorElement.selectedTextRange

    let lines = content.breakLines(appendLineBreakToLastLine: false)
    let selections: [CursorRange] = {
      if let selectedTextRange {
        return [Self.convertRangeToCursorRange(
          selectedTextRange,
          in: lines)]
      }
      return []
    }()

    let lineAnnotationElements = editorElement.caching({
      $0.children.filter { $0.identifier == "Line Annotation" }
    }, cacheKey: "line-annotations")
    let lineAnnotations = lineAnnotationElements.compactMap(\.description)

    updateStateWith(
      content: content,
      selections: selections,
      compilerMessages: lineAnnotations)
  }

  private func updateStateWith(
    content: String? = nil,
    selections: [CursorRange]? = nil,
    compilerMessages: [String]? = nil)
  {
    let currentState = internalState.value
    let newState = InternalXcodeEditorState(
      fileName: fileName,
      id: id,
      content: content ?? currentState.content,
      selections: selections ?? currentState.selections,
      compilerMessages: compilerMessages ?? currentState.compilerMessages)
    if newState != currentState {
      internalState.send(newState)
    }
  }

}

extension String {
  /// The line ending of the string.
  ///
  /// We are pretty safe to just check the last character here, in most case, a line ending
  /// will be in the end of the string.
  ///
  /// For other situations, we can assume that they are "\n".
  public var lineEnding: Character {
    if let last, last.isNewline { return last }
    return "\n"
  }

  public func splitByNewLine(
    omittingEmptySubsequences: Bool = true,
    fast: Bool = true)
    -> [Substring]
  {
    if fast {
      let lineEndingInText = lineEnding
      return split(
        separator: lineEndingInText,
        omittingEmptySubsequences: omittingEmptySubsequences)
    }
    return split(
      omittingEmptySubsequences: omittingEmptySubsequences,
      whereSeparator: \.isNewline)
  }

  /// Break a string into lines.
  public func breakLines(
    proposedLineEnding: String? = nil,
    appendLineBreakToLastLine: Bool = false)
    -> [String]
  {
    let lineEndingInText = lineEnding
    let lineEnding = proposedLineEnding ?? String(lineEndingInText)
    // Split on character for better performance.
    let lines = split(separator: lineEndingInText, omittingEmptySubsequences: false)
    var all = [String]()
    for (index, line) in lines.enumerated() {
      if !appendLineBreakToLastLine, index == lines.endIndex - 1 {
        all.append(String(line))
      } else {
        all.append(String(line) + lineEnding)
      }
    }
    return all
  }
}

extension SourceEditorObserver {
  static func convertCursorRangeToRange(
    _ cursorRange: CursorRange,
    in lines: [String])
    -> CFRange
  {
    var countS = 0
    var countE = 0
    var range = CFRange(location: 0, length: 0)
    for (i, line) in lines.enumerated() {
      if i == cursorRange.start.line {
        countS = countS + cursorRange.start.character
        range.location = countS
      }
      if i == cursorRange.end.line {
        countE = countE + cursorRange.end.character
        range.length = max(countE - range.location, 0)
        break
      }
      countS += line.utf16.count
      countE += line.utf16.count
    }
    return range
  }

  static func convertCursorRangeToRange(
    _ cursorRange: CursorRange,
    in content: String)
    -> CFRange
  {
    let lines = content.breakLines(appendLineBreakToLastLine: false)
    return convertCursorRangeToRange(cursorRange, in: lines)
  }

  static func convertRangeToCursorRange(
    _ range: ClosedRange<Int>,
    in lines: [String])
    -> CursorRange
  {
    guard !lines.isEmpty else { return CursorRange(start: .zero, end: .zero) }
    var countS = 0
    var countE = 0
    var cursorRange = CursorRange(start: .zero, end: .outOfScope)
    for (i, line) in lines.enumerated() {
      if
        countS <= range.lowerBound,
        // when equal, means the cursor is located at the lowerBound
        range.lowerBound <= countS + line.utf16.count
      {
        cursorRange.start = .init(line: i, character: range.lowerBound - countS)
      }
      if
        countE <= range.upperBound,
        range.upperBound < countE + line.utf16.count
      {
        cursorRange.end = .init(line: i, character: range.upperBound - countE)
        break
      }
      countS += line.utf16.count
      countE += line.utf16.count
    }
    if cursorRange.end == .outOfScope {
      cursorRange.end = .init(
        line: lines.endIndex - 1,
        character: lines.last?.utf16.count ?? 0)
    }
    return cursorRange
  }

  static func convertRangeToCursorRange(
    _ range: ClosedRange<Int>,
    in content: String)
    -> CursorRange
  {
    let lines = content.breakLines(appendLineBreakToLastLine: false)
    return convertRangeToCursorRange(range, in: lines)
  }
}
