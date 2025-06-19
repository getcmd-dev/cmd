// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppEventServiceInterface
import AppFoundation
import ChatAppEvents
import ChatFoundation
import ChatHistoryServiceInterface
import Combine
import Dependencies
import Foundation
import FoundationInterfaces
import LLMFoundation
import LoggingServiceInterface
import Observation
import SwiftUI
import XcodeObserverServiceInterface

// MARK: - ChatViewModel

@MainActor @Observable
public class ChatViewModel {

  #if DEBUG
  convenience init(
    defaultMode: ChatMode? = nil,
    tab: ChatTabViewModel = ChatTabViewModel())
  {
    self.init(
      defaultMode: defaultMode ?? .agent,
      tab: tab,
      currentModel: .claudeSonnet_4_0)
  }
  #endif

  public convenience init(defaultMode: ChatMode? = nil) {
    self.init(
      defaultMode: defaultMode ?? .agent,
      tab: ChatTabViewModel(),
      currentModel: .claudeSonnet_4_0)
  }

  private init(
    defaultMode: ChatMode,
    tab: ChatTabViewModel,
    currentModel: LLMModel)
  {
    self.tab = tab
    self.currentModel = currentModel
    self.defaultMode = defaultMode
    registerAsAppEventHandler()

    xcodeObserver.statePublisher.map(\.focusedWorkspace).map(\.?.url).removeDuplicates()
      .sink { @Sendable [weak self] focusedWorkspacePath in
        Task { @MainActor in
          self?.focusedWorkspacePath = focusedWorkspacePath
        }
      }.store(in: &cancellables)

    Task {
      await loadPersistedChatThreads()
    }
  }

  private(set) var tab: ChatTabViewModel
  var currentModel: LLMModel
  var selectedFile: URL?

  // TODO: persist to user defaults and load
  var defaultMode: ChatMode
  private(set) var focusedWorkspacePath: URL? = nil
  private(set) var showChatHistory = false

  @ObservationIgnored @Dependency(\.chatHistoryService) var chatHistoryService: ChatHistoryService

  let chatHistory = ChatHistoryViewModel()

  func handleShowChatHistory() {
    showChatHistory = true
  }

  func handleHideChatHistory() {
    showChatHistory = false
  }

  func handleSelectChatThread(id: UUID) {
    Task {
      await selectChatThread(id: id)
    }
  }

  /// Create a new tab/thread.
  /// - Parameter copyingCurrentInput: Whether the current input content should be ported to the new tab.
  func addTab(copyingCurrentInput: Bool = false) {
    let newTab = ChatTabViewModel()
    let currentTab = tab
    tab = newTab
    if copyingCurrentInput {
      newTab.input = currentTab.input.copy(didTapSendMessage: { Task { [weak newTab] in await newTab?.sendMessage() } })
    }
  }

  // MARK: - Persistence Methods

  func loadPersistedChatThreads() async {
    do {
      guard
        let persistentTabInfo = try await chatHistoryService.loadLastChatThreads(last: 1, offset: 0).first,
        let thread = try await chatHistoryService.loadChatThread(id: persistentTabInfo.id)
      else {
        return
      }
      let chatTab = ChatTabViewModel(from: thread)

      tab = chatTab

      defaultLogger.log("Loaded chat tabs from database")
    } catch {
      defaultLogger.error("Failed to load chat tabs from database", error)
    }
  }

  @ObservationIgnored private var cancellables = Set<AnyCancellable>()

  @ObservationIgnored @Dependency(\.appEventHandlerRegistry) private var appEventHandlerRegistry
  @ObservationIgnored @Dependency(\.xcodeObserver) private var xcodeObserver
  @ObservationIgnored @Dependency(\.fileManager) private var fileManager

  private func selectChatThread(id: UUID) async {
    do {
      guard let thread = try await chatHistoryService.loadChatThread(id: id) else {
        defaultLogger.error("Could not find chat thread \(id)")
        showChatHistory = false
        return
      }

      tab = ChatTabViewModel(from: thread)
      showChatHistory = false
    } catch {
      showChatHistory = false
      defaultLogger.error("Failed to load chat thread with id \(id)", error)
    }
  }

  private func registerAsAppEventHandler() {
    appEventHandlerRegistry.registerHandler { [weak self] event in
      guard let self else { return false }
      if let event = event as? AddCodeToChatEvent {
        await handle(addCodeToChatEvent: event)
        return true //
      } else if let event = event as? ChangeChatModeEvent {
        Task { @MainActor in
          self.tab.input.mode = event.chatMode
        }
        return true
      } else if event is NewChatEvent {
        await addTab(copyingCurrentInput: true)
        return true
      } else {
        return false
      }
    }
  }

  private func handle(addCodeToChatEvent event: AddCodeToChatEvent) {
    Task { @MainActor in
      if !ProcessInfo.processInfo.isRunningInTestEnvironment {
        NSApp.setActivationPolicy(.regular)
        // TODO: make sure the app is activated. Sometimes it doesn't work.
        Task { try await NSApplication.activateCurrentApp() }
      }

      if event.newThread {
        self.addTab()
      }
      if let chatMode = event.chatMode {
        self.tab.input.mode = chatMode
      }

      self.tab.input.textInputNeedsFocus = true

      if let workspace = xcodeObserver.state.focusedWorkspace {
        let handled = addCodeSelection(from: workspace)
        if !handled {
          // Add log for debugging.
          if
            let axInfo = xcodeObserver.state.wrapped?.xcodesState.first?.workspaces.first?.axElement.wrappedValue?
              .debugDescription
          {
            defaultLogger.log(axInfo as String)
          }
        }
      } else {
        defaultLogger.log("No workspace found to handle add to code to chat event")
      }
    }
  }

  private func addCodeSelection(from workspace: XcodeWorkspaceState) -> Bool {
    let inputModel = tab.input
    let editor = workspace.editors.first(where: { $0.isFocused })
    if editor?.fileName != workspace.document?.lastPathComponent {
      if let document = workspace.document, let content = try? fileManager.read(contentsOf: document) {
        inputModel.add(attachment: .file(.init(path: document, content: content)))
        return true
      }
    }
    guard let editor else {
      defaultLogger.log("No editor found to handle add to code to chat event")
      return false
    }

    let content = editor.content
    guard !content.isEmpty else {
      defaultLogger.log("No content found in the focus editor to handle add to code to chat event")
      return false
    }
    guard let filePath = workspace.tabs.first(where: { $0.fileName == editor.fileName })?.knownPath else {
      defaultLogger.log("Could not resolve file path for file \(editor.fileName) to handle add to code to chat event")
      return false
    }
    if let selection = editor.selections.first, selection.start != selection.end {
      inputModel.add(attachment: .fileSelection(.init(
        file: .init(path: filePath, content: content),
        startLine: selection.start.line + 1,
        endLine: selection.end.line + 1)))
    } else {
      inputModel.add(attachment: .file(.init(path: filePath, content: content)))
    }
    return true
  }

}

extension NSApplication {
  static func activateCurrentApp() async throws {
    NSApplication.shared.activate(ignoringOtherApps: true)
    let activated = NSRunningApplication.current.activate()
    if activated { return }
    let appleScript = """
      tell application "System Events"
          set frontmost of the first process whose unix id is \
      \(ProcessInfo.processInfo.processIdentifier) to true
      end tell
      """
    try await runAppleScript(appleScript)
  }

  @discardableResult
  static func runAppleScript(_ appleScript: String) async throws -> String {
    let task = Process()
    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-e", appleScript]
    let outpipe = Pipe()
    task.standardOutput = outpipe
    task.standardError = Pipe()

    return try await withUnsafeThrowingContinuation { continuation in
      do {
        task.terminationHandler = { _ in
          do {
            if
              let data = try outpipe.fileHandleForReading.readToEnd(),
              let content = String(data: data, encoding: .utf8)
            {
              continuation.resume(returning: content)
              return
            }
            continuation.resume(returning: "")
          } catch {
            continuation.resume(throwing: error)
          }
        }
        try task.run()
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }
}
