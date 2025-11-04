// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppFoundation
import AppKit
import ChatAppEvents
import CodeCompletionFoundation
import CodeCompletionServiceInterface
@preconcurrency import Combine
import ConcurrencyFoundation
import DependencyFoundation
import Foundation
import SettingsServiceInterface
import XcodeObserverServiceInterface

// MARK: - WorkspaceIndex

// TODO: buffer updates for file change (don't do every char)
// TODO: get tabSize etc, maybe from XcodeExtension?
// TODO: setup file watched to detect file save.
// TODO: check if URL is a stable key for dictionaries

/// A representation of the files in a workspace.
/// The list of files is kept up to date.
final class WorkspaceIndex: Workspace {
  init(url: URL, root: URL, files: @escaping @Sendable () -> [URL]) {
    self.url = url
    self.root = root
    _files = files
  }

  let root: URL
  let url: URL
  let _files: @Sendable () -> [URL]

  var files: [URL] { _files() }

}

// MARK: - DefaultCodeCompletionService

actor DefaultCodeCompletionService: CodeCompletionService {
  init(
    xcodeObserver: XcodeObserver,
    getPasteboardContent: @escaping @Sendable () -> String?,
    codeCompletionProviders: [any CodeCompletionProvider],
    settingsService: SettingsService)
  {
    self.xcodeObserver = xcodeObserver
    self.getPasteboardContent = getPasteboardContent
    self.codeCompletionProviders = codeCompletionProviders
    self.settingsService = settingsService

    // Subscribe to state changes from XcodeObserver
    let cancellable = xcodeObserver.statePublisher.sink { @Sendable newState in
      Task { [weak self] in
        await self?.handleStateChange(newState)
      }
    }
    Task {
      await add(cancellable: cancellable)
    }
  }

  var configuredProvider: (any CodeCompletionProvider)? {
    if let id = settingsService.value(for: \.codeCompletionProviderId) {
      return codeCompletionProviders.first(where: { $0.id == id })
    }
    return nil
  }

  // TODO: support timeout
  func suggestCompletion(
    workspace: URL,
    file: URL,
    content: String,
    selection: Range,
    timeout _: TimeInterval)
    async throws -> CompletionSuggestion?
  {
    guard let provider = configuredProvider else {
      throw AppError("No code completion provider configured")
    }
    if let fileState = openFiles[workspace]?[file], fileState.content == content {
      // Nothing
    } else {
      openFiles[workspace] = openFiles[workspace] ?? [:]
      openFiles[workspace]?[file] = .init(content: content, version: 0)
      notifyProviders { provider in
        provider.didOpen(workspace: workspace, file: file, content: content, version: 0)
      }
    }

    return try await provider.suggestCompletion(
      workspace: workspace,
      file: file,
      content: content,
      version: openFiles[workspace]?[file]?.version ?? 0,
      selection: selection,
      pasteboardContent: getPasteboardContent())
  }

  nonisolated func logCompletionAcceptance(suggestion _: CompletionSuggestion, accepted _: Bool) { }

  private struct FileState {
    let content: String
    let version: Int
  }

  /// State of workspace initialization
  private enum WorkspaceState {
    case initializing
    case ready
    case failed
  }

  /// Track workspace initialization state to prevent race conditions
  private var workspaceStates = [URL: WorkspaceState]()
  private let xcodeObserver: XcodeObserver
  private let getPasteboardContent: @Sendable () -> String?
  private let codeCompletionProviders: [any CodeCompletionProvider]
  private let settingsService: SettingsService
  private var cancellables = Set<AnyCancellable>()

  /// Track which files are currently open within each workspace
  nonisolated private let filesPerWorkspace = Atomic([URL: Set<URL>]())
  private var openFiles = [URL: [URL: FileState]]()

  private func add(cancellable: AnyCancellable) {
    cancellables.insert(cancellable)
  }

  private func initialize(workspace: URL) {
    // Prevent duplicate initialization - only start if workspace is not already initializing or ready
    // Allow retry if previous initialization failed
    let currentState = workspaceStates[workspace]
    guard currentState != .initializing, currentState != .ready else { return }

    workspaceStates[workspace] = .initializing

    Task { [weak self] in
      do {
        // list files
        let workspaceInfo = try await self?.xcodeObserver.listFiles(in: workspace)
        let files = workspaceInfo?.files
        let workspaceRoot = workspaceInfo?.workspaceRoot ?? workspace
        await self?.didInitialize(workspace: workspace, workspaceRoot: workspaceRoot, files: files, success: true)
        // setup file watcher (TODO)
      } catch {
        print("Error setting up workspace: \(error)")
        await self?.didInitialize(workspace: workspace, workspaceRoot: workspace, files: nil, success: false)
      }
    }
  }

  private func didInitialize(workspace: URL, workspaceRoot: URL, files: [URL]?, success _: Bool) {
    if let files {
      filesPerWorkspace[workspace] = Set(files)
      notifyProviders { provider in
        provider.setUp(workspace: WorkspaceIndex(
          url: workspace,
          root: workspaceRoot,
          files: { [weak self] in self?.filesPerWorkspace[workspace]?.sorted(by: { $0.path < $1.path }) ?? [] }))
      }
      openFiles[workspace] = [:]
      workspaceStates[workspace] = .ready
      // Process any pending state changes now that initialization is complete
      handleStateChange(xcodeObserver.state)
    } else {
      // Failed initialization - mark as failed but don't set openFiles
      // This allows retry on next state change
      workspaceStates[workspace] = .failed
    }
  }

  /// Handle state changes from XcodeObserver and emit appropriate LSP events
  private func handleStateChange(_ newState: AXState<XcodeState>) {
    guard let state = newState.wrapped else { return }

    // Track all currently open files in all workspaces
    var currentlyOpenFiles = [URL: Set<URL>]()
    var currentlyTrackedWorkspaces = Set<URL>()

    for xcodeApp in state.xcodesState {
      for workspace in xcodeApp.workspaces {
        currentlyTrackedWorkspaces.insert(workspace.url)
        if openFiles[workspace.url] == nil {
          // new workspace - start initialization
          initialize(workspace: workspace.url)
          // Skip processing events for this workspace until initialization completes
          continue
        }
        openFiles[workspace.url] = openFiles[workspace.url, default: [:]]
        currentlyOpenFiles[workspace.url] = currentlyOpenFiles[workspace.url, default: Set()]

        for tab in workspace.tabs {
          if let fileURL = tab.knownPath, let content = tab.lastKnownContent {
            currentlyOpenFiles[workspace.url]?.insert(fileURL)

            // textDocument/didOpen: Detect newly opened files
            if openFiles[workspace.url]?[fileURL] == nil {
              openFiles[workspace.url]?[fileURL] = .init(content: content, version: 0)
              notifyProviders { provider in
                provider.didOpen(workspace: workspace.url, file: fileURL, content: content, version: 0)
              }
            }

            // textDocument/didChange: Detect content changes
            if let fileState = openFiles[workspace.url]?[fileURL], fileState.content != content {
              let version = fileState.version + 1
              openFiles[workspace.url]?[fileURL] = .init(content: content, version: version)
              notifyProviders { provider in
                provider.didChange(workspace: workspace.url, file: fileURL, content: content, version: version)
              }
            }
          }
        }
      }
    }

    for (workspaceURL, openFilesInWorkspace) in openFiles {
      if !currentlyTrackedWorkspaces.contains(workspaceURL) {
        // Stop tracking the workspace if it's no longer open
        notifyProviders { $0.close(workspace: workspaceURL) }
      }
      // textDocument/didClose: Detect files that were closed
      let currentlyOpenFiles = currentlyOpenFiles[workspaceURL] ?? Set()
      let closedFiles = openFilesInWorkspace.keys.filter { !currentlyOpenFiles.contains($0) }
      for fileURL in closedFiles {
        if let fileState = openFiles[workspaceURL]?[fileURL] {
          openFiles[workspaceURL]?.removeValue(forKey: fileURL)
          notifyProviders { provider in
            provider.didClose(workspace: workspaceURL, file: fileURL, content: fileState.content, version: fileState.version)
          }
        }
      }
    }
  }

  /// Helper to notify all providers of an event
  private func notifyProviders(_ action: (any CodeCompletionProvider) -> Void) {
    for provider in codeCompletionProviders {
      action(provider)
    }
  }

}

extension CursorRange {
  var range: Range {
    .init(
      start: .init(line: start.line, character: start.character),
      end: .init(line: end.line, character: end.character))
  }
}

extension BaseProviding where
  Self: XcodeObserverProviding,
  Self: CodeCompletionProvidersPluginProviding,
  Self: SettingsServiceProviding
{
  public var codeCompletionService: CodeCompletionService {
    shared {
      DefaultCodeCompletionService(
        xcodeObserver: xcodeObserver,
        getPasteboardContent: { NSPasteboard.general.string(forType: .string) },
        codeCompletionProviders: codeCompletionProviders,
        settingsService: settingsService)
    }
  }
}
