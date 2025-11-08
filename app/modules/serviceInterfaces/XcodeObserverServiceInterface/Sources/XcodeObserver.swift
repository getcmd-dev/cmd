// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import Combine
import ConcurrencyFoundation
import Foundation

// MARK: - XcodeObserver

public protocol XcodeObserver: Sendable {
  var statePublisher: ReadonlyCurrentValueSubject<AXState<XcodeState>, Never> { get }
  var axNotifications: AnyPublisher<AXNotification, Never> { get }
  /// Return the content of the file.
  /// The read strategy (IDE version / from disk) should match the write strategy defined in `fileEditMode`.
  func getContent(of file: URL) throws -> String
  /// List the files in the Xcode workspace.
  /// Included files are visible to Xcode, and tracked by git if in a git repo.
  func listFiles(in workspace: URL, debounce: TimeInterval?) async throws -> ListFilesResult
  ///
  func filterIgnoredFiles(from files: [URL], in workspace: URL) async -> [URL]
}

// MARK: - WorkspaceType

public enum WorkspaceType {
  case xcodeProject
  case swiftPackage
  case directory
}

// MARK: - ListFilesResult

public struct ListFilesResult {
  public let files: [URL]
  public let workspaceType: WorkspaceType
  public let workspaceRoot: URL

  public init(files: [URL], workspaceType: WorkspaceType, workspaceRoot: URL) {
    self.files = files
    self.workspaceType = workspaceType
    self.workspaceRoot = workspaceRoot
  }
}

extension XcodeObserver {
  public var state: AXState<XcodeState> {
    statePublisher.currentValue
  }

  /// The URL of the file currently focussed in the IDE, if any.
  public var focusedTabURL: URL? {
    get async {
      guard let workspace = state.focusedWorkspace else { return nil }
      return await focusedTabURL(in: workspace)
    }
  }

  /// The content of the file, as last observed in the IDE.
  /// Note: if the file has not yet been opened in the IDE, or if the observation was started after the file was focussed, this content is unknown.
  public func knownEditorContent(of file: URL) -> String? {
    state.wrapped?.xcodesState.compactMap { xc in
      xc.workspaces.compactMap { ws in
        ws.tabs.compactMap { tab in
          tab.knownPath == file ? tab.lastKnownContent : nil
        }.first
      }.first
    }.first
  }

  /// The URL of the file currently focussed in the workspace, if any.
  public func focusedTabURL(in workspace: XcodeWorkspaceState) async -> URL? {
    if let path = workspace.tabs.first(where: { $0.isFocused })?.knownPath {
      return path
    } else if
      // The Accessibility API, which Xcode observer uses to set the `knownPath`,
      // only gives the absolute path for the file focussed on the first editor tab.
      // So in split screen mode, if the user focuses on the second tab, this value is missing.
      // We therefore perform a more expensive operation to list all files in the workspace to find a match.

      let editor = workspace.editors.first(where: { $0.isFocused }),
      let matchingFiles = try? await listFiles(in: workspace.url).files
        .filter({ $0.lastPathComponent == editor.fileName }),
      matchingFiles.count == 1,
      let path = matchingFiles.first
    {
      return path
    }
    return nil
  }

  public func listFiles(in workspace: URL) async throws -> ListFilesResult {
    try await listFiles(in: workspace, debounce: nil)
  }
}

extension AXState<XcodeState> {

  /// The instance of Xcode that is currently active (Xcode will be inactive if the host app is active and this would then be `nil`).
  public var activeInstance: XcodeAppState? {
    wrapped?.xcodesState
      .first(where: { $0.isActive })
  }

  /// The instance of Xcode that is either active or was last used.
  public var focusedInstance: XcodeAppState? {
    wrapped?.xcodesState
      .first
  }

  public var focusedWorkspace: XcodeWorkspaceState? {
    // Why is it not-reordered?
    focusedInstance?.workspaces.filter(\.isFocused)
      .first ??
      focusedInstance?.workspaces
      .first
  }

  public var focussedEditor: XcodeEditorState? {
    focusedWorkspace?.focussedEditor
  }
}

extension XcodeWorkspaceState {

  public var focussedEditor: XcodeEditorState? {
    editors.filter(\.isFocused).first ??
      editors.first
  }
}

// MARK: - XcodeObserverProviding

public protocol XcodeObserverProviding {
  var xcodeObserver: XcodeObserver { get }
}

// MARK: - IsHostAppActiveProviding

public protocol IsHostAppActiveProviding {
  var isHostAppActive: AnyPublisher<Bool, Never> { get }
}
