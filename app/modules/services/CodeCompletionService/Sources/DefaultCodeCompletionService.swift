// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppEventServiceInterface
import AppFoundation
import AppKit
import ChatAppEvents
import CodeCompletionFoundation
import CodeCompletionServiceInterface
@preconcurrency import Combine
import DependencyFoundation
import Foundation
import SettingsServiceInterface
import XcodeObserverServiceInterface

// MARK: - DefaultCodeCompletionService

// TODO: buffer updates for file change (don't do every char)
// TODO: get tabSize etc, maybe from XcodeExtension?
// TODO: setup file watched to detect file save.
// TODO: check if URL is a stable key for dictionaries

actor DefaultCodeCompletionService: CodeCompletionService {
  init(
    xcodeObserver: XcodeObserver,
    getPasteboardContent: @escaping @Sendable () -> String?,
    codeCompletionProviders: [any CodeCompletionProvider],
    settingsService: SettingsService,
    appEventHandlerRegistry: AppEventHandlerRegistry)
  {
    self.xcodeObserver = xcodeObserver
    self.getPasteboardContent = getPasteboardContent
    self.codeCompletionProviders = codeCompletionProviders
    self.settingsService = settingsService
    appEventHandlerRegistry.registerHandler { [weak self] appEvent in
      if let appEvent = appEvent as? SuggestCodeCompletionEvent {
        Task {
          try await self?.suggestCompletion(timeout: 10)
        }
        return true
      }
      return false
    }

    // Set up event sources from XcodeObserver
    Task {
      await setupEventSources()
    }
  }

  deinit {
    for cancellable in cancellables { cancellable.cancel() }
  }

  var configuredProvider: (any CodeCompletionProvider)? {
    if let id = settingsService.value(for: \.codeCompletionProviderId) {
      return codeCompletionProviders.first(where: { $0.id == id })
    }
    // TODO: remove
    return codeCompletionProviders.first
//    return nil
  }

  // TODO: support timeout
  func suggestCompletion(timeout _: TimeInterval) async throws -> CompletionSuggestion? {
    guard let provider = configuredProvider else {
      throw AppError("No code completion provider configured")
    }
    guard let workspace = xcodeObserver.state.focusedWorkspace else {
      throw AppError("No focused Xcode workspace")
    }
    guard let focussedFile = await xcodeObserver.focusedTabURL(in: workspace) else {
      throw AppError("No focused file in Xcode workspace")
    }
    guard let fileState = openFiles[workspace.url]?[focussedFile] else {
      throw AppError("No content for focused file in Xcode workspace")
    }
    guard let editor = workspace.editors.first(where: { $0.isFocused }) else {
      throw AppError("No focused editor in Xcode workspace")
    }
    let selections = editor.selections
    guard selections.count == 1, let selection = selections.first else {
      throw AppError("Multiple selections are not supported")
    }

    return try await provider.suggestCompletion(
      workspace: workspace.url,
      file: focussedFile,
      content: fileState.content,
      version: fileState.version,
      selection: selection.range,
      pasteboardContent: getPasteboardContent())
  }

  nonisolated func logCompletionAcceptance(suggestion _: CompletionSuggestion, accepted _: Bool) { }

  private struct FileState {
    let content: String
    let version: Int
  }

  private let xcodeObserver: XcodeObserver
  private let getPasteboardContent: @Sendable () -> String?
  private let codeCompletionProviders: [any CodeCompletionProvider]
  private let settingsService: SettingsService
  private var cancellables = [AnyCancellable]()

  /// Track which files are currently open within each workspace
  private var openFiles = [URL: [URL: FileState]]()

  /// Set up event sources from XcodeObserver to trigger LSP text document events
  private func setupEventSources() {
    // Subscribe to state changes from XcodeObserver
    xcodeObserver.statePublisher.sink { @Sendable newState in
      Task { [weak self] in
        await self?.handleStateChange(newState)
      }
    }.store(in: &cancellables)
  }

  /// Handle state changes from XcodeObserver and emit appropriate LSP events
  private func handleStateChange(_ newState: AXState<XcodeState>) {
    guard let state = newState.wrapped else { return }

    // Track all currently open files in all workspaces
    var currentlyOpenFiles = [URL: Set<URL>]()

    for xcodeApp in state.xcodesState {
      for workspace in xcodeApp.workspaces {
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
  Self: SettingsServiceProviding,
  Self: AppEventHandlerRegistryProviding
{
  public var codeCompletionService: CodeCompletionService {
    shared {
      DefaultCodeCompletionService(
        xcodeObserver: xcodeObserver,
        getPasteboardContent: { NSPasteboard.general.string(forType: .string) },
        codeCompletionProviders: codeCompletionProviders,
        settingsService: settingsService,
        appEventHandlerRegistry: appEventHandlerRegistry)
    }
  }
}
