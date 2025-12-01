// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AccessibilityFoundation
import AppFoundation
import AppKit
import ChatAppEventsFoundation
import CodeCompletionFoundation
import CodeCompletionServiceInterface
@preconcurrency import Combine
import ConcurrencyFoundation
import DependencyFoundation
import Foundation
import FoundationInterfaces
import LoggingServiceInterface
import PermissionsServiceInterface
import SettingsServiceInterface
import SharedValuesFoundation
import ShellServiceInterface
import XcodeControllerServiceInterface
import XcodeObserverServiceInterface

// MARK: - CodeCompletionIsolation

// TODO: buffer updates for file change (don't do every char)
// TODO: check if URL is a stable key for dictionaries

// MARK: - CodeCompletionIsolation

@globalActor
actor CodeCompletionIsolation {
  static let shared = CodeCompletionIsolation()
}

// MARK: - DefaultCodeCompletionService

@CodeCompletionIsolation
final class DefaultCodeCompletionService: CodeCompletionService {
  nonisolated init(
    xcodeObserver: XcodeObserver,
    getPasteboardContent: @escaping @Sendable () -> String?,
    codeCompletionProviders: [any CodeCompletionProvider],
    settingsService: SettingsService,
    fileManager: FileManagerI,
    shellService: ShellService,
    xcodeController: XcodeController,
    permissionsService: PermissionsService)
  {
    self.xcodeObserver = xcodeObserver
    self.getPasteboardContent = getPasteboardContent
    self.codeCompletionProviders = codeCompletionProviders
    self.settingsService = settingsService
    self.fileManager = fileManager
    self.shellService = shellService
    self.xcodeController = xcodeController
    self.permissionsService = permissionsService

    // DefaultCodeCompletionService and APIBasedCodeCompletionProvider depends on each other.
    // So we complete hooking them up post init.
    codeCompletionProviders
      .compactMap({ $0 as? APIBasedCodeCompletionProvider })
      .forEach { $0.recentEditsTrackers = { [weak self] url in
        await self?.editTracker(for: url)
      }}

    var cancellables = Set<AnyCancellable>()
    permissionsService.status(for: .xcodeExtension).sink { @Sendable value in
      Task { [weak self] in
        await self?.handle(xcodeExtensionPermissionIsGranted: value)
      }
    }.store(in: &cancellables)

    settingsService.liveValue(for: \.enableCodeCompletion).sink { @Sendable value in
      Task { [weak self] in
        await self?.handle(enableCodeCompletionSettingChanged: value)
      }
    }.store(in: &cancellables)

    // Subscribe to state changes from XcodeObserver
    xcodeObserver.statePublisher.sink { @Sendable newState in
      Task { [weak self] in
        await self?.handleStateChange(newState)
      }
    }.store(in: &cancellables)
    let _cancellables = cancellables
    Task {
      for cancellable in _cancellables {
        await add(cancellable: cancellable)
      }
    }
  }

  /// Track recent edits per workspace (workspace URL -> tracker)
  private(set) var recentEditsTrackers = [WorkspaceIndex: RecentEditsTracker]()

  /// Cache formatting metadata per workspace
  var formattingMetadataCache = [WorkspaceIndex: FileFormattingMetadata]()

  nonisolated var isAvailable: ReadonlyCurrentValueSubject<Bool> {
    _isAvailable.readonly()
  }

  var configuredProvider: (any CodeCompletionProvider)? {
    if let id = settingsService.value(for: \.codeCompletionProviderId) {
      return codeCompletionProviders.first(where: { $0.id == id })
    }
    return nil
  }

  /// Return the recent edits tracker for a workspace.
  func editTracker(for workspaceURL: URL) -> RecentEditsTracker? {
    guard let workspace = workspaces[workspaceURL] else {
      return nil
    }
    return recentEditsTrackers[workspace]
  }

  // TODO: support timeout
  func suggestCompletion(_ request: CompletionRequest) async throws -> (cachedRequestId: Int, suggestion: CompletionSuggestion)? {
    let file = request.file
    let workspace = request.workspace
    let content = request.content
    let selection = request.selection
    guard isAvailable.value else {
      return nil
    }
    guard let provider = configuredProvider else {
      throw AppError("No code completion provider configured")
    }
    guard let workspace = workspaces[workspace] else {
      throw AppError("Workspace \(workspace.path) not tracked")
    }

    if let fileState = openFiles[workspace]?[file], fileState.content == content {
      // Nothing
    } else {
      openFiles[workspace] = openFiles[workspace] ?? [:]
      openFiles[workspace]?[file] = .init(content: content, version: 0)
      // Update tracker before notifying providers
      recentEditsTrackers[workspace]?.process(updates: [(url: file, content: content)])
      notifyProviders { provider in
        provider.didOpen(workspace: workspace, file: file, content: content, version: 0)
      }
    }
    let request = CompletionCacheRequest(workspace: workspace.url, file: file, content: content, selection: selection)

    // Get formatting metadata for the workspace
    let formattingMetadata = await getFormattingMetadata(for: workspace)

    let suggestion = try await provider.suggestCompletion(
      workspace: workspace,
      file: file,
      content: content,
      version: openFiles[workspace]?[file]?.version ?? 0,
      selection: selection,
      pasteboardContent: getPasteboardContent(),
      formattingMetadata: formattingMetadata)?
      .applied(to: content, file: file, selection: selection)

    if let suggestion, suggestion.containsNonWhitespaceCompletion {
      defaultLogger.trace("Got completion suggestion \(suggestion.diff.debugDescription)")
      let cacheId = cachedCompletions.store(suggestion: suggestion, for: request)
      return (cachedRequestId: cacheId, suggestion: suggestion)
    } else {
      _ = cachedCompletions.store(suggestion: nil, for: request)
    }
    return nil
  }

  nonisolated func deleteCachedCompletion(cachedRequestId: Int) {
    cachedCompletions.remove(cachedRequestId: cachedRequestId)
  }

  nonisolated func cachedCompletion(_ request: CompletionRequest) throws
    -> (cachedRequestId: Int, suggestion: CompletionSuggestion?)?
  {
    let file = request.file
    let workspace = request.workspace
    let content = request.content
    let selection = request.selection
    guard isAvailable.value else {
      return nil
    }
    let request = CompletionCacheRequest(workspace: workspace, file: file, content: content, selection: selection)

    if let (cacheId, cachedCompletion) = cachedCompletions.get(for: request) {
      if let cachedCompletion, !cachedCompletion.containsNonWhitespaceCompletion {
        return nil
      }
      defaultLogger.log("Returning cached completion \(cachedCompletion?.diff.debugDescription ?? "nil")")
      return (cachedRequestId: cacheId, suggestion: cachedCompletion)
    }
    return nil
  }

  nonisolated func logCompletionAcceptance(
    suggestion _: CompletionSuggestion,
    accepted _: Bool) { }

  /// Handle state changes from XcodeObserver and emit appropriate LSP events
  func handleStateChange(_ newState: AXState<XcodeState>) {
    guard let state = newState.wrapped else { return }

    // Track all currently open files in all workspaces
    var currentlyOpenFiles = [URL: Set<URL>]()
    var currentlyTrackedWorkspaces = Set<URL>()

    for xcodeApp in state.xcodesState {
      for workspaceState in xcodeApp.workspaces {
        currentlyTrackedWorkspaces.insert(workspaceState.url)
        if let workspace = workspaces[workspaceState.url] {
          openFiles[workspace] = openFiles[workspace, default: [:]]
          currentlyOpenFiles[workspace.url] = currentlyOpenFiles[workspace.url, default: Set()]

          // Batch updates for this workspace
          var trackerUpdates = [(url: URL, content: String?)]()
          var didOpenEvents = [(file: URL, content: String, version: Int)]()
          var didChangeEvents = [(file: URL, content: String, version: Int)]()

          for tab in workspaceState.tabs {
            if let fileURL = tab.knownPath, let content = tab.lastKnownContent {
              currentlyOpenFiles[workspace.url]?.insert(fileURL)

              // textDocument/didOpen: Detect newly opened files
              if openFiles[workspace]?[fileURL] == nil {
                openFiles[workspace]?[fileURL] = .init(content: content, version: 0)
                trackerUpdates.append((url: fileURL, content: content))
                didOpenEvents.append((file: fileURL, content: content, version: 0))
              }

              // textDocument/didChange: Detect content changes
              if let fileState = openFiles[workspace]?[fileURL], fileState.content != content {
                let version = fileState.version + 1
                openFiles[workspace]?[fileURL] = .init(content: content, version: version)
                trackerUpdates.append((url: fileURL, content: content))
                didChangeEvents.append((file: fileURL, content: content, version: version))
              }
            }
          }

          // Send batch update to tracker
          if !trackerUpdates.isEmpty {
            recentEditsTrackers[workspace]?.process(updates: trackerUpdates)
          }

          // Send all updates to providers
          for event in didOpenEvents {
            notifyProviders { provider in
              provider.didOpen(workspace: workspace, file: event.file, content: event.content, version: event.version)
            }
          }
          for event in didChangeEvents {
            notifyProviders { provider in
              provider.didChange(workspace: workspace, file: event.file, content: event.content, version: event.version)
            }
          }
        } else {
          // new workspace - start initialization
          initialize(workspaceURL: workspaceState.url)
          // Skip processing events for this workspace until initialization completes
          continue
        }
      }
    }

    for (workspace, openFilesInWorkspace) in openFiles {
      if !currentlyTrackedWorkspaces.contains(workspace.url) {
        // Stop tracking the workspace if it's no longer open
        fileWatchers.removeValue(forKey: workspace)
        openFiles.removeValue(forKey: workspace)
        filesPerWorkspace.mutate({ $0.removeValue(forKey: workspace) })
        recentEditsTrackers.removeValue(forKey: workspace)
        notifyProviders { $0.close(workspace: workspace.url) }
      }
      // textDocument/didClose: Detect files that were closed
      let currentlyOpenFiles = currentlyOpenFiles[workspace.url] ?? Set()
      let closedFiles = openFilesInWorkspace.keys.filter { !currentlyOpenFiles.contains($0) }
      for fileURL in closedFiles {
        if let fileState = openFiles[workspace]?[fileURL] {
          openFiles[workspace]?.removeValue(forKey: fileURL)
          notifyProviders { provider in
            provider.didClose(workspace: workspace, file: fileURL, content: fileState.content, version: fileState.version)
          }
        }
      }
    }
  }

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

  private nonisolated let cachedCompletions = CompletionCache()

  nonisolated private let _isAvailable = CurrentValueSubject<Bool, Never>(false)

  /// Track workspace initialization state to prevent race conditions
  private var workspaceStates = [URL: WorkspaceState]()
  private nonisolated let workspaces = Atomic<[URL: WorkspaceIndex]>([:])
  private let xcodeObserver: XcodeObserver
  private let getPasteboardContent: @Sendable () -> String?
  private let codeCompletionProviders: [any CodeCompletionProvider]
  private let settingsService: SettingsService
  private let fileManager: FileManagerI
  private let shellService: ShellService
  private let xcodeController: XcodeController
  private let permissionsService: PermissionsService
  private var cancellables = Set<AnyCancellable>()

  /// Track file watchers for each workspace
  private var fileWatchers = [WorkspaceIndex: AnyCancellable]()

  /// Track which files are currently open within each workspace
  nonisolated private let filesPerWorkspace = Atomic([WorkspaceIndex: Set<URL>]())
  private var openFiles = [WorkspaceIndex: [URL: FileState]]()

  private func handle(xcodeExtensionPermissionIsGranted _: PermissionStatus) {
    updateIsAvailable()
  }

  private func handle(enableCodeCompletionSettingChanged _: Bool) {
    updateIsAvailable()
  }

  private func updateIsAvailable() {
    let hasPermission = {
      #if DEBUG
      // Debug builds don't work well with Xcode extension.
      // The permission is typically not granted to DEBUG builds, that instead trigger extension request through the release app.
      permissionsService.status(for: .xcodeExtension).value.isGranted ||
        settingsService.value(for: \.pointReleaseXcodeExtensionToDebugApp)
      #else
      permissionsService.status(for: .xcodeExtension).value.isGranted
      #endif
    }()
    let isEnabledInSettings = settingsService.value(for: \.enableCodeCompletion)
    let isAvailable = hasPermission && isEnabledInSettings
    _isAvailable.send(isAvailable)
  }

  private func add(cancellable: AnyCancellable) {
    cancellables.insert(cancellable)
  }

  private func initialize(workspaceURL: URL) {
    // Prevent duplicate initialization - only start if workspace is not already initializing or ready
    // Allow retry if previous initialization failed
    let currentState = workspaceStates[workspaceURL]
    guard currentState != .initializing, currentState != .ready else { return }

    workspaceStates[workspaceURL] = .initializing

    let xcodeObserver = xcodeObserver
    Task { [weak self] in
      do {
        // list files
        let workspaceInfo = try await xcodeObserver.listFiles(in: workspaceURL)
        guard let self else { return }
        let files = workspaceInfo.files
        let workspaceRoot = workspaceInfo.workspaceRoot
        let workspace = WorkspaceIndex(
          url: workspaceURL,
          root: workspaceRoot,
          files: { [weak self] in
            if let workspace = self?.workspaces[workspaceURL] {
              return self?.filesPerWorkspace[workspace]?.sorted(by: { $0.path < $1.path }) ?? []
            }
            return []
          })
        workspaces[workspaceURL] = workspace
        filesPerWorkspace[workspace] = Set(files)
        openFiles[workspace] = [:]
        workspaceStates[workspace.url] = .ready
        recentEditsTrackers[workspace] = RecentEditsTracker(root: workspaceRoot)

        // Setup file watcher for the workspace root
        setupFileWatcher(for: workspace, root: workspaceRoot)

        notifyProviders { provider in
          provider.setUp(workspace: workspace)
        }
        // Process any pending state changes now that initialization is complete
        handleStateChange(xcodeObserver.state)
      } catch {
        // Failed initialization - mark as failed but don't set openFiles
        // This allows retry on next state change
        self?.workspaceStates[workspaceURL] = .failed
        defaultLogger.error("Error setting up workspace", error)
      }
    }
  }

  /// Helper to notify all providers of an event
  private func notifyProviders(_ action: (any CodeCompletionProvider) -> Void) {
    for provider in codeCompletionProviders {
      action(provider)
    }
  }

  /// Setup file watcher for a workspace to detect file changes on disk
  private func setupFileWatcher(for workspace: WorkspaceIndex, root: URL) {
    do {
      fileWatchers[workspace] = try fileManager.observeDirectory(at: root) { [weak self] events in
        Task { [weak self] in
          await self?.handleFileSystemEvents(workspace: workspace, events: events)
        }
      }
    } catch {
      defaultLogger.error("Error setting up file watcher for workspace \(workspace)", error)
    }
  }

  /// Handle file system events detected by FSEvents
  private func handleFileSystemEvents(workspace: WorkspaceIndex, events: [FileSystemEvent]) async {
    guard let openFilesInWorkspace = openFiles[workspace] else { return }
    var eventURLs = await Set(xcodeObserver.filterIgnoredFiles(
      from: events.map { URL(fileURLWithPath: $0.path) },
      in: workspace.url))
    if eventURLs.isEmpty { return }

    // Refresh the list of files in the workspace.
    // We do this using `listFiles` instead of adding files from `events` because we only track files visible to Xcode
    // (and tracked in git) while the file watcher watches the entire workspace directory tree.
    // `listFiles` has a debouncing mechanism to reduce load on excessive calls, limiting CPU impact.
    // The introduced delay is an acceptable tradeoff, since updating the list of files is not particularly time-sensitive.
    guard let currentWorkspaceFiles = try? await xcodeObserver.listFiles(in: workspace.url, debounce: 5).files else {
      return
    }
    let currentWorkspaceFilesSet = Set(currentWorkspaceFiles)
    let previouslyTrackedFiles = filesPerWorkspace[workspace] ?? Set()

    eventURLs = eventURLs
      .intersection(currentWorkspaceFilesSet.union(previouslyTrackedFiles))
    filesPerWorkspace[workspace] = currentWorkspaceFilesSet
    guard !eventURLs.isEmpty else { return }

    // Batch updates for this workspace
    var trackerUpdates = [(url: URL, content: String?)]()
    var didSaveEvents = [(file: URL, content: String, version: Int)]()
    var didDeleteEvents = [URL]()

    // TODO: look at tracking changes made outside of Xcode?
    // Process only events for files that are currently open
    for event in events {
      let eventURL = URL(fileURLWithPath: event.path)

      if !eventURLs.contains(eventURL) {
        continue
      }

      // Check if this event is for an open file
      guard let fileState = openFilesInWorkspace[eventURL] else { continue }

      // Handle file modifications
      if event.isModified || event.isInodeMetadataModified {
        do {
          let contentOnDisk = try fileManager.read(contentsOf: eventURL)
          if contentOnDisk != fileState.content {
            // File was saved - update the cached content
            let version = fileState.version + 1
            openFiles[workspace]?[eventURL] = .init(content: contentOnDisk, version: version)
            trackerUpdates.append((url: eventURL, content: contentOnDisk))
            didSaveEvents.append((file: eventURL, content: contentOnDisk, version: version))
          }
        } catch {
          // Failed to read file - check if it still exists to distinguish between deletion and other errors
          if fileManager.fileExists(atPath: eventURL.path) {
            // File exists but can't be read (permission issues, newly created empty file, etc.)
            // Skip notification for this event - the file will be handled when it becomes readable
          } else {
            // File was deleted - clear from openFiles to reset lifecycle
            openFiles[workspace]?.removeValue(forKey: eventURL)
            trackerUpdates.append((url: eventURL, content: nil))
            didDeleteEvents.append(eventURL)
          }
        }
      }
    }

    // Send batch update to tracker
    if !trackerUpdates.isEmpty {
      recentEditsTrackers[workspace]?.process(updates: trackerUpdates)
    }

    // Send all updates to providers
    for event in didSaveEvents {
      notifyProviders { provider in
        provider.didSave(workspace: workspace, file: event.file, content: event.content, version: event.version)
      }
    }
    for fileURL in didDeleteEvents {
      notifyProviders { provider in
        provider.didDelete(workspace: workspace, file: fileURL)
      }
    }
  }

  /// Get or fetch formatting metadata for a workspace
  /// Metadata is cached per workspace and fetched from the currently focused file in Xcode
  private func getFormattingMetadata(for workspace: WorkspaceIndex) async -> FileFormattingMetadata? {
    // Check cache first (cached by workspace)
    if let cached = formattingMetadataCache[workspace] {
      return cached
    }

    // Fetch from Xcode extension for the currently focused file
    do {
      let metadata = try await xcodeController.getFormattingMetadata()
      // Cache by workspace
      formattingMetadataCache[workspace] = metadata
      return metadata
    } catch {
      defaultLogger.error("Failed to get formatting metadata for workspace \(workspace.url.path)", error)
      return nil
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
  Self: FileManagerProviding,
  Self: ShellServiceProviding,
  Self: XcodeControllerProviding,
  Self: PermissionsServiceProviding
{
  public var codeCompletionService: CodeCompletionService {
    shared {
      DefaultCodeCompletionService(
        xcodeObserver: xcodeObserver,
        getPasteboardContent: { NSPasteboard.general.string(forType: .string) },
        codeCompletionProviders: codeCompletionProviders,
        settingsService: settingsService,
        fileManager: fileManager,
        shellService: shellService,
        xcodeController: xcodeController,
        permissionsService: permissionsService)
    }
  }
}
