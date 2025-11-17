// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppFoundation
import AppKit
@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import LoggingServiceInterface
import ThreadSafe
import XcodeObserverServiceInterface

// MARK: - XcodeWorkspaceObserver

@ThreadSafe
final class XcodeWorkspaceObserver: AXElementObserver, @unchecked Sendable {
  @MainActor
  init(runningApplication: NSRunningApplication, workspace: AXUIElement, url: URL) {
    logger.trace("XcodeWorkspaceObserver #\(id) init")
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
    observeChangesToFocussedEditor()
    pullFocussedEditorState()
  }

  deinit {
    logger.trace("XcodeWorkspaceObserver #\(id) deinit")
  }

  let id = UUID().uuidString

  let workspaceURL: URL
  var editorObservers = [SourceEditorObserver]()

  let workspace: AXUIElement

  var state: ReadonlyCurrentValueSubject<InternalXcodeWorkspaceState> {
    .init(internalState.value, publisher: internalState.eraseToAnyPublisher())
  }

  /// Parse the workspace AX tree. Ensure that we are observing any visible editor, and collect tab information.
  @MainActor
  func refresh(force: Bool = false) {
    guard
      let editorArea = workspace.caching(
        {
          $0.firstChild(where: { el, _ in
            let description = el.description
            if description == "editor area" {
              return .stopSearching
            } else if description == "scroll area" {
              return .skipDescendants
            }
            return .continueSearching
          })
        },
        cacheKey: "editor-area",
        force: force)
    else {
      return
    }
    let editorContexts = editorArea.children(where: { el, _ in
      el.identifier == "editor context" ? .stopSearching : .continueSearching
    })
    .compactMap { el in el.firstParent(where: { $0.description?.starts(with: el.description ?? "<NA>") == true }) }

    let editorsContainer = editorContexts.first?.caching({
      $0.firstParent(where: { $0.role == kAXSplitGroupRole })
    }, cacheKey: "editors-container", force: force)

    // Update editor inspectors.
    guard
      let editorObservers = editorsContainer?.children
        .compactMap({ editorContainer in
          editorObserver(for: editorContainer)
        })
    else {
      return
    }
    let removedEditorObservers = editorObservers.filter { inspector in
      !self.editorObservers.contains(where: { $0 === inspector })
    }
    removedEditorObservers.forEach(stopTracking(_:))
    self.editorObservers = editorObservers

    // Update tabs
    let tabEls = editorsContainer?.children.flatMap { $0
      .firstChild(where: { el, _ in el.roleDescription == "tab group" ? .stopSearching : .continueSearching })?
      .children(where: { el, _ in el.roleDescription == "tab" ? .stopSearching : .continueSearching }) ?? []
    } ?? []
    // When in tabless mode, there are no tab elements. Use the editor context name instead.
    let fallbackFocusTabName = editorContexts.first?.caching({
      $0.firstChild(where: { el, _ in el.identifier == "editor context" ? .stopSearching : .continueSearching })
    }, cacheKey: "fallback-tab-name", force: force)?.description
    // Use a set as there are several hierachies of tabs that can contain the same file.
    // Sort to avoid unnucessary state updates.
    let tabNames = Array(Set(tabEls.compactMap(\.title) + (fallbackFocusTabName.map { [$0] } ?? []))).sorted()
    let existingTabs = internalState.value.tabs
    let focusedTabName = tabEls.first(where: { $0.doubleValue == 1 })?.title ?? fallbackFocusTabName
    let documentURL = workspace.documentURL

    let focusEditorState = editorObservers.lazy.compactMap { editor in
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

    let focusedEditorId: String?? = editorObservers.first(where: { $0.editorElement.isFocused })?.id ?? nil

    updateStateWith(
      tabs: tabs,
      editors: editorObservers.map(\.state.currentValue).sorted(by: { $1.id == focusedEditorId }),
      documentURL: workspace.documentURL,
      focusedEditorId: focusedEditorId,
      focusedTabName: focusedTabName)
  }

  private var axSubscription: AnyCancellable?

  private let runningApplication: NSRunningApplication

  private let internalState: CurrentValueSubject<InternalXcodeWorkspaceState, Never>

  private func pullFocussedEditorState() {
    Task { @MainActor [weak self] in
      while let self {
        try? await Task.sleep(for: .seconds(1))
        let focusedEditorId: String?? = editorObservers.first(where: { $0.editorElement.isFocused })?.id ?? nil
        if focusedEditorId != state.currentValue.focusedEditorId {
          logger.log("Workspace observer: pullFocussedEditorState updating focussed editor to: \(focusedEditorId ??? "nil")")
        }
        updateStateWith(focusedEditorId: focusedEditorId)
      }
    }
  }

  @MainActor
  private func observeChangesToFocussedEditor() {
    guard
      let axNotificationPublisher = try? AXNotificationPublisher(
        app: runningApplication,
        // Note: setting `workspace` belows leads to receiving no notifications.
        // So we listen to app wide notifications, and might will receive notifications from other windows as well.
        // This should not be a problem given how we handle the notification.
        element: nil,
        notificationNames:
        kAXFocusedUIElementChangedNotification)
    else {
      logger.error("Failed to create AXNotificationPublisher")
      return
    }

    axSubscription = axNotificationPublisher.sink { [weak self] notification in
      // Note: the notification might come from another window / workspace.
      guard let self else { return }
      guard let event = AXNotification(rawValue: notification.name) else {
        return
      }
      if notification.element.isSourceEditor, !editorObservers.contains(where: { $0.editorElement == notification.element }) {
        // Track the editor
        refresh(force: true)
      }
      // AXTextArea -  / description: Source Editor

      switch event {
      case .focusedUIElementChanged:
        let focusedEditorId: String? = editorObservers.first(where: { $0.editorElement == notification.element })?.id ?? nil
        updateStateWith(
          focusedEditorId: focusedEditorId)

      default: break
      }
    }
  }

  /// Returns the inspector for the corresponding editor.
  /// If the inspector is already created, it returns the existing inspector.
  /// If the inspector is not created, it creates a new inspector and subscribes to it.
  @MainActor
  private func editorObserver(for editorContainer: AXUIElement) -> SourceEditorObserver? {
    if
      let inspector = editorObservers
        .filter(\.isElementValid)
        .first(where: { $0.element == editorContainer })
    {
      return inspector
    }
    guard
      let editorElement = editorContainer.firstChild(where: { el, _ in el.isSourceEditor ? .stopSearching : .continueSearching }),
      let observer = SourceEditorObserver(runningApplication: runningApplication, editorElement: editorElement)
    else {
      return nil
    }

    startTracking(observer)
    return observer
  }

  @MainActor
  private func startTracking(_ observer: SourceEditorObserver) {
    let editors = internalState.value.editors
    updateStateWith(editors: editors + [observer.state.currentValue])

    let cancellable = observer
      .state
      .sink { [weak self] newValue in
        guard let self else { return }
        let editors = internalState.value.editors
        updateStateWith(editors: editors.map { oldValue in oldValue.id == newValue.id ? newValue : oldValue })
      }
    observer.set(cleanupTask: cancellable)
    observer.onElementInvalidated = { [weak self] observer in
      self?.handleElementBecameInvalid(for: observer)
    }
    editorObservers.append(observer)
  }

  private func stopTracking(_ inspector: SourceEditorObserver) {
    inLock { state in
      state.editorObservers = state.editorObservers.filter { $0 !== inspector }
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

extension AXUIElement {
  var isSourceEditor: Bool {
    role == kAXTextAreaRole && description == "Source Editor"
  }
}
