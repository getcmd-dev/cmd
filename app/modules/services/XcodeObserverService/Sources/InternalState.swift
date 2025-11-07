// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppKit
import XcodeObserverServiceInterface

// MARK: - InternalXcodeState

// The "internal" states match closely those defined in `XcodeObserverServiceInterface`,
// but some of the data might be represented at different levels in the hierarchy based on where the source of truth is.
// They are re-mapped to a structure that makes more sense for consumption when being broadcasted.

struct InternalXcodeState: Sendable, Equatable {
  let activeApplicationProcessIdentifier: Int32?
  let previousApplicationProcessIdentifier: Int32?
  let xcodesState: [InternalXcodeAppState]
}

// MARK: - InternalXcodeAppState

struct InternalXcodeAppState: Sendable, Equatable {
  let processIdentifier: Int32
  let workspaces: [InternalXcodeWorkspaceState]
  let focusedWorkspaceURL: URL?
}

// MARK: - InternalXcodeWorkspaceState

struct InternalXcodeWorkspaceState: Sendable, Equatable {
  let axElement: AnyAXUIElement
  let url: URL
  let document: URL?
  let tabs: [Tab]
  let editors: [InternalXcodeEditorState]
  let focusedTabName: String?
  let focusedEditorId: String?

  struct Tab: Sendable, Equatable {
    let fileName: String
    /// Through the AX API, Xcode only gives the path to the current file. Other tabs only contain the file name.
    /// Overtime, if we are able to get the path of different tabs as they are focused, we keep track of this association.
    let knownPath: URL?
    let lastKnownContent: String?
  }
}

// MARK: - InternalXcodeEditorState

struct InternalXcodeEditorState: Sendable, Equatable {
  let axElement: AnyAXUIElement
  let fileName: String
  let id: String
  let content: String
  let selections: [CursorRange]
  let compilerMessages: [String]
}

extension InternalXcodeState {
  var normalized: XcodeState {
    XcodeState(
      activeApplicationProcessIdentifier: activeApplicationProcessIdentifier,
      previousApplicationProcessIdentifier: previousApplicationProcessIdentifier,
      xcodesState: xcodesState.map { $0.normalized(activePid: activeApplicationProcessIdentifier) })
  }
}

// MARK: - InternalXcodeAppState

extension InternalXcodeAppState {
  func normalized(activePid: Int32?) -> XcodeAppState {
    XcodeAppState(
      processIdentifier: processIdentifier,
      isActive: processIdentifier == activePid,
      workspaces: workspaces.map { $0.normalized(focusedWorkspaceURL: focusedWorkspaceURL) })
  }
}

extension InternalXcodeWorkspaceState {
  func normalized(focusedWorkspaceURL: URL?) -> XcodeWorkspaceState {
    XcodeWorkspaceState(
      axElement: axElement,
      url: url,
      editors: editors.map { $0.normalized(focusedEditorId: focusedEditorId) },
      isFocused: url == focusedWorkspaceURL,
      document: document,
      tabs: tabs.map { $0.normalized(focusedTabName: focusedTabName) })
  }
}

extension InternalXcodeWorkspaceState.Tab {
  func normalized(focusedTabName: String?) -> XcodeWorkspaceState.Tab {
    XcodeWorkspaceState.Tab(
      fileName: fileName,
      isFocused: fileName == focusedTabName,
      knownPath: knownPath,
      lastKnownContent: lastKnownContent)
  }
}

extension InternalXcodeEditorState {
  func normalized(focusedEditorId: String?) -> XcodeEditorState {
    XcodeEditorState(
      axElement: axElement,
      fileName: fileName,
      isFocused: id == focusedEditorId,
      content: content,
      selections: selections,
      compilerMessages: compilerMessages)
  }
}

extension AXState<InternalXcodeState> {
  var normalized: AXState<XcodeState> {
    switch self {
    case .unknown:
      .unknown
    case .missingAXPermission:
      .missingAXPermission
    case .state(let state):
      .state(state.normalized)
    }
  }
}
