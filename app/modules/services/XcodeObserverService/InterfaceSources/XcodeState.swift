// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
// MARK: - XcodeState
import Foundation

// MARK: - AXState

public enum AXState<State: Sendable & Equatable>: Sendable, Equatable {
  case unknown
  case missingAXPermission
  case state(_: State)

  public var wrapped: State? {
    switch self {
    case .state(let state):
      state
    default:
      nil
    }
  }
}

// MARK: - XcodeState

public struct XcodeState: Sendable, Equatable {
  public init(
    activeApplicationProcessIdentifier: Int32?,
    previousApplicationProcessIdentifier: Int32?,
    xcodesState: [XcodeAppState])
  {
    self.activeApplicationProcessIdentifier = activeApplicationProcessIdentifier
    self.previousApplicationProcessIdentifier = previousApplicationProcessIdentifier
    self.xcodesState = xcodesState
  }

  public let activeApplicationProcessIdentifier: Int32?
  public let previousApplicationProcessIdentifier: Int32?
  public let xcodesState: [XcodeAppState] // TODO: remove "state" from var name
}

// MARK: - XcodeAppState

public struct XcodeAppState: Sendable, Equatable {
  public let processIdentifier: Int32
  public let isActive: Bool
  public let workspaces: [XcodeWorkspaceState]

  public init(processIdentifier: Int32, isActive: Bool, workspaces: [XcodeWorkspaceState]) {
    self.processIdentifier = processIdentifier
    self.isActive = isActive
    self.workspaces = workspaces
  }
}

// MARK: - XcodeWorkspaceState

public struct XcodeWorkspaceState: Sendable, Equatable {

  public init(axElement: AnyAXUIElement, url: URL, editors: [XcodeEditorState], isFocused: Bool, document: URL?, tabs: [Tab]) {
    self.axElement = axElement
    self.url = url
    self.editors = editors
    self.isFocused = isFocused
    self.document = document
    self.tabs = tabs
  }

  public struct Tab: Sendable, Equatable {
    public let fileName: String
    public let isFocused: Bool
    /// Through the AX API, Xcode only gives the path to the current file. Other tabs only contain the file name.
    /// Overtime, if we are able to get the path of different tabs as they are focused, we keep track of this association.
    public let knownPath: URL?
    /// The tab's content when it was last visible in the editor.
    /// If the file is not saved yet, or if the file was changed on disk outside of Xcode while it was not visible in Xcode, this might differ from the content on disk.
    public let lastKnownContent: String?

    public init(fileName: String, isFocused: Bool, knownPath: URL?, lastKnownContent: String?) {
      self.fileName = fileName
      self.isFocused = isFocused
      self.knownPath = knownPath
      self.lastKnownContent = lastKnownContent
    }
  }

  public let axElement: AnyAXUIElement
  /// The location of the .xcproj / .xcworkspace corresponding to the open window.
  public let url: URL
  /// The editor panels visible in the workspace.
  public let editors: [XcodeEditorState]
  /// Wether this workspace is the one focussed for the given instance.
  public let isFocused: Bool
  /// The document currently focussed in the workspace (some documents, like plist, might not be presented in an editor)
  public let document: URL?
  /// All the open tabs in the workspace. They might be open across several editors / or tab levels (Xcode has two tab levels...).
  public let tabs: [Tab]

}

// MARK: - XcodeEditorState

public struct XcodeEditorState: Sendable, Equatable {
  public let fileName: String
  public let isFocused: Bool
  public let content: String
  public let selections: [CursorRange]
  public let compilerMessages: [String]

  public init(fileName: String, isFocused: Bool, content: String, selections: [CursorRange], compilerMessages: [String]) {
    self.fileName = fileName
    self.isFocused = isFocused
    self.content = content
    self.selections = selections
    self.compilerMessages = compilerMessages
  }
}

// MARK: - CursorPosition

public struct CursorPosition: Equatable, Codable, Hashable, Sendable {
  public static let zero = CursorPosition(line: 0, character: 0)

  public let line: Int
  public let character: Int

  public init(line: Int, character: Int) {
    self.line = line
    self.character = character
  }

  public init(_ pair: (Int, Int)) {
    line = pair.0
    character = pair.1
  }
}

// MARK: Comparable

extension CursorPosition: Comparable {
  public static func <(lhs: CursorPosition, rhs: CursorPosition) -> Bool {
    if lhs.line == rhs.line {
      return lhs.character < rhs.character
    }

    return lhs.line < rhs.line
  }
}

extension CursorPosition {
  public static var outOfScope: CursorPosition { .init(line: -1, character: -1) }

  public var readableText: String {
    "L\(line + 1):\(character)"
  }

  public var readableTextWithoutCharacter: String {
    "L\(line + 1)"
  }
}

// MARK: - CursorRange

public struct CursorRange: Codable, Hashable, Sendable, Equatable, CustomStringConvertible {

  public init(start: CursorPosition, end: CursorPosition) {
    self.start = start
    self.end = end
  }

  public init(startPair: (Int, Int), endPair: (Int, Int)) {
    start = CursorPosition(startPair)
    end = CursorPosition(endPair)
  }

  public static let zero = CursorRange(start: .zero, end: .zero)

  public var start: CursorPosition
  public var end: CursorPosition

  public var isEmpty: Bool {
    start == end
  }

  public var isOneLine: Bool {
    start.line == end.line
  }

  /// The number of lines in the range.
  public var lineCount: Int {
    end.line - start.line + 1
  }

  public var description: String {
    if start != end {
      "[\(start.readableText) - \(end.readableText)]"
    } else {
      "[\(start.readableText)]"
    }
  }

  public func contains(_ position: CursorPosition) -> Bool {
    position >= start && position <= end
  }

  public func contains(_ range: CursorRange) -> Bool {
    range.start >= start && range.end <= end
  }

  public func strictlyContains(_ range: CursorRange) -> Bool {
    range.start > start && range.end < end
  }
}

extension CursorRange {
  public static var outOfScope: CursorRange { .init(start: .outOfScope, end: .outOfScope) }

  public static func cursor(_ position: CursorPosition) -> CursorRange {
    .init(start: position, end: position)
  }
}
