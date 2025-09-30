// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppKit
@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import ThreadSafe
import XcodeObserverServiceInterface

// MARK: - XcodeWorkspaceObserver

@ThreadSafe
final class XcodeWorkspaceObserver: AXElementObserver, @unchecked Sendable {
  @MainActor
  init(runningApplication: NSRunningApplication, workspace: AXUIElement, url: URL) {
    self.runningApplication = runningApplication
    self.workspace = workspace
    workspaceURL = url
    let state = InternalXcodeWorkspaceState(
      axElement: AnyAXUIElement(workspace),
      url: workspaceURL,
      document: workspace.documentURL,
      tabs: [],
      editors: [],
      focusedTabName: nil,
      focusedEditorId: nil)
    internalState = CurrentValueSubject<InternalXcodeWorkspaceState, Never>(state)

    super.init(element: workspace)

    refresh()
  }

  let workspaceURL: URL
  var editorInspectors = [SourceEditorObserver]()

  let workspace: AXUIElement

  var state: ReadonlyCurrentValueSubject<InternalXcodeWorkspaceState, Never> {
    .init(internalState.value, publisher: internalState.eraseToAnyPublisher())
  }

  /// Parse the workspace AX tree. Ensure that we are observing any visible editor, and collect tab information.
  @MainActor
  func refresh() {
    guard
      let editorArea = workspace.caching({
        $0.firstChild(where: { el, _ in
          let description = el.description
          if description == "editor area" {
            return .stopSearching
          } else if description == "scroll area" {
            return .skipDescendants
          }
          return .continueSearching
        })
      }, cacheKey: "editor-area")
    else {
      return
    }
    let editorContexts = editorArea.caching({
      $0.children(where: { el, _ in
        el.identifier == "editor context" ? .stopSearching : .continueSearching
      })
      .compactMap { el in el.firstParent(where: { $0.description?.starts(with: el.description ?? "<NA>") == true }) }
    }, cacheKey: "editor-contexts")

    let editorsContainer = editorContexts.first?.caching({
      $0.firstParent(where: { $0.role == kAXSplitGroupRole })
    }, cacheKey: "editors-container")

    // Update editor inspectors.
    guard
      let editorInspectors = editorsContainer?.caching({ $0.children }, cacheKey: "editor-containers")
        .compactMap({ editorContainer in
          editorInspector(for: editorContainer)
        })
    else {
      return
    }
    let removedInspectors = editorInspectors.filter { inspector in
      !self.editorInspectors.contains(where: { $0 === inspector })
    }
    removedInspectors.forEach(stopTracking(_:))
    self.editorInspectors = editorInspectors

    // Update tabs
    let tabEls = editorsContainer?.caching({
      $0.children.flatMap { $0
        .firstChild(where: { el, _ in el.roleDescription == "tab group" ? .stopSearching : .continueSearching })?
        .children(where: { el, _ in el.roleDescription == "tab" ? .stopSearching : .continueSearching }) ?? []
      }
    }, cacheKey: "tabs") ?? []
    // When in tabless mode, there are no tab elements. Use the editor context name instead.
    let fallbackFocusTabName = editorContexts.first?.caching({
      $0.firstChild(where: { el, _ in el.identifier == "editor context" ? .stopSearching : .continueSearching })
    }, cacheKey: "fallback-tab-name")?.description
    // Use a set as there are several hierachies of tabs that can contain the same file.
    // Sort to avoid unnucessary state updates.
    let tabNames = Array(Set(tabEls.compactMap(\.title) + (fallbackFocusTabName.map { [$0] } ?? []))).sorted()
    let existingTabs = internalState.value.tabs
    let focusedTabName = tabEls.first(where: { $0.doubleValue == 1 })?.title ?? fallbackFocusTabName
    let documentURL = workspace.documentURL

    let focusEditorState = editorInspectors.lazy.compactMap { editor in
      let state = editor.state.currentValue
      return state.fileName == focusedTabName ? state : nil
    }.first

    let tabs = tabNames.map { tabName in
      let existingTab = existingTabs.first(where: { $0.fileName == tabName })
      if tabName == focusedTabName {
        return InternalXcodeWorkspaceState.Tab(
          fileName: tabName,
          knownPath: documentURL ?? existingTab?.knownPath,
          lastKnownContent: focusEditorState?.content ?? existingTab?.lastKnownContent)
      }
      return existingTab ?? .init(fileName: tabName, knownPath: nil, lastKnownContent: nil)
    }

    let focusedEditorId: String?? = editorInspectors.first(where: { $0.editorElement.isFocused })?.id ?? nil

    updateStateWith(
      tabs: tabs,
      editors: editorInspectors.map(\.state.currentValue).sorted(by: { $1.id == focusedEditorId }),
      documentURL: workspace.documentURL,
      focusedEditorId: focusedEditorId,
      focusedTabName: focusedTabName)
  }

  private let runningApplication: NSRunningApplication

  private let internalState: CurrentValueSubject<InternalXcodeWorkspaceState, Never>

  /// Returns the inspector for the corresponding editor.
  /// If the inspector is already created, it returns the existing inspector.
  /// If the inspector is not created, it creates a new inspector and subscribes to it.
  @MainActor
  private func editorInspector(for editorContainer: AXUIElement) -> SourceEditorObserver? {
    if
      let inspector = editorInspectors
        .filter(\.isElementValid)
        .first(where: { $0.element == editorContainer })
    {
      return inspector
    }
    guard
      let editorElement = editorContainer.firstChild(where: { el, _ in el.isSourceEditor ? .stopSearching : .continueSearching }),
      let inspector = SourceEditorObserver(runningApplication: runningApplication, editorElement: editorElement)
    else {
      return nil
    }

    startTracking(inspector)
    return inspector
  }

  @MainActor
  private func startTracking(_ inspector: SourceEditorObserver) {
    let editors = internalState.value.editors
    updateStateWith(editors: editors + [inspector.state.currentValue])

    let cancellable = inspector
      .state
      .sink { [weak self] newValue in
        guard let self else { return }
        let editors = internalState.value.editors
        updateStateWith(editors: editors.map { oldValue in oldValue.id == newValue.id ? newValue : oldValue })
      }
    inspector.set(cleanupTask: cancellable)
    inspector.onElementInvalidated = { [weak self] inspector in
      self?.handleElementBecameInvalid(for: inspector)
    }
    editorInspectors.append(inspector)
  }

  private func stopTracking(_ inspector: SourceEditorObserver) {
    inLock { state in
      state.editorInspectors = state.editorInspectors.filter { $0 !== inspector }
    }
  }

  private func updateStateWith(
    tabs: [InternalXcodeWorkspaceState.Tab]? = nil,
    editors: [InternalXcodeEditorState]? = nil,
    documentURL: URL?? = nil,
    focusedEditorId: String?? = nil,
    focusedTabName: String?? = nil)
  {
    let state = internalState.value
    // update the content with that of the editor when possible.
    let tabs = (tabs ?? state.tabs).map { tab -> InternalXcodeWorkspaceState.Tab in
      if let editor = editors?.first(where: { $0.fileName == tab.fileName }) {
        return InternalXcodeWorkspaceState.Tab(
          fileName: tab.fileName,
          knownPath: tab.knownPath,
          lastKnownContent: editor.content)
      } else {
        return tab
      }
    }
    let newState = InternalXcodeWorkspaceState(
      axElement: state.axElement,
      url: state.url,
      document: documentURL ?? state.document,
      tabs: tabs,
      editors: editors ?? state.editors,
      focusedTabName: focusedTabName ?? state.focusedTabName,
      focusedEditorId: focusedEditorId ?? state.focusedEditorId)
    if state != newState {
      internalState.send(newState)
    }
  }

  @MainActor
  private func handleElementBecameInvalid(for _: AXElementObserver) {
    refresh()
  }
}
