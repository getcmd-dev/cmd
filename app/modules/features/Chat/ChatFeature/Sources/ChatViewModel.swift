// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppEventServiceInterface
import AppFoundation
import ChatAppEvents
import ChatCompletionServiceInterface
import ChatFoundation
import ChatHistoryServiceInterface
import ChatServiceInterface
import Combine
import Dependencies
import Foundation
import FoundationInterfaces
import LLMFoundation
import LLMServiceInterface
import LoggingServiceInterface
import Observation
import SwiftUI
import XcodeObserverServiceInterface

// MARK: - ChatViewModel

@MainActor @Observable
public class ChatViewModel {

  #if DEBUG
  convenience init(
    tab: ChatThreadViewModel = ChatThreadViewModel())
  {
    self.init(
      tab: tab,
      currentModel: .claudeSonnet)
  }
  #endif

  public convenience init() {
    self.init(
      tab: ChatThreadViewModel(),
      currentModel: .claudeSonnet)
  }

  private init(
    tab: ChatThreadViewModel,
    currentModel: AIModel)
  {
    tab.isFocused = true
    tabs = [tab]
    currentTabIndex = 0
    self.currentModel = currentModel

    @Dependency(\.appEventHandlerRegistry) var appEventHandlerRegistry
    @Dependency(\.xcodeObserver) var xcodeObserver
    @Dependency(\.fileManager) var fileManager
    @Dependency(\.chatHistoryService) var chatHistoryService
    @Dependency(\.chatService) var chatService
    @Dependency(\.userDefaults) var userDefaults
    @Dependency(\.llmService) var llmService
    self.appEventHandlerRegistry = appEventHandlerRegistry
    self.xcodeObserver = xcodeObserver
    self.fileManager = fileManager
    self.chatHistoryService = chatHistoryService
    self.chatService = chatService
    self.userDefaults = userDefaults
    self.llmService = llmService

    chatService.buffer(tab, for: tab.id)

    registerAsAppEventHandler()

    xcodeObserver.statePublisher.map(\.focusedWorkspace).map(\.?.url).removeDuplicates()
      .sink { @Sendable [weak self] focusedWorkspacePath in
        Task { @MainActor in
          self?.focusedWorkspacePath = focusedWorkspacePath
        }
      }.store(in: &cancellables)

    Task {
      await loadPersistedChatThreads()
      @Dependency(\.chatCompletion) var chatCompletion
      chatCompletion.register(delegate: self)
    }
  }

  var currentModel: AIModel
  var selectedFile: URL?
  private(set) var focusedWorkspacePath: URL? = nil
  private(set) var showChatHistory = false

  let chatHistoryService: ChatHistoryService
  let chatService: ChatService
  let userDefaults: UserDefaultsI
  let llmService: LLMService

  let chatHistory = ChatHistoryViewModel()

  /// All open tabs
  private(set) var tabs = [ChatThreadViewModel]()

  /// Index of the currently active tab
  private(set) var currentTabIndex = 0

  /// The currently active tab
  var tab: ChatThreadViewModel {
    get {
      guard currentTabIndex >= 0, currentTabIndex < tabs.count else {
        assertionFailure("currentTabIndex set to \(currentTabIndex) which is out of bound [0-\(tabs.count)[")
        // Fallback: create a default tab if none exists
        let defaultTab = ChatThreadViewModel()
        defaultTab.isFocused = true
        tabs = [defaultTab]
        currentTabIndex = 0
        saveTabState()
        return defaultTab
      }
      return tabs[currentTabIndex]
    }
    set {
      if currentTabIndex >= 0, currentTabIndex < tabs.count {
        tabs[currentTabIndex] = newValue
        chatService.buffer(newValue, for: newValue.id)
        saveLastOpenThreadId(newValue.id)
      }
    }
  }

  func handleShowChatHistory() {
    showChatHistory = true
  }

  func handleHideChatHistory() {
    showChatHistory = false
  }

  func handleSelectChatThread(id: UUID) async {
    await selectChatThread(id: id)
  }

  /// Create a new tab/thread.
  /// - Parameter copyingCurrentInput: Whether the current input content should be ported to the new tab.
  func addTab(copyingCurrentInput: Bool = false, threadId: UUID? = nil) {
    let currentTab = tab

    // If the current tab is empty and we're creating a new tab (not opening an existing thread),
    // don't create a new tab - just reuse the current empty tab
    if threadId == nil && currentTab.isEmpty {
      if copyingCurrentInput {
        // Input is already in the current tab, nothing to do
      }
      // The current tab is already focused, no need to change focus or create a new tab
      return
    }

    let newTab = threadId.map { chatService.knownObject(for: $0) } ??? ChatThreadViewModel(id: threadId)
    if copyingCurrentInput {
      newTab.input = currentTab.input.copy(
        didTapSendMessage: { Task { [weak newTab] in await newTab?.sendMessage() } },
        didCancelMessage: { newTab.cancelCurrentMessage() })
    }
    // Unfocus the previously selected tab
    if currentTabIndex >= 0, currentTabIndex < tabs.count {
      tabs[currentTabIndex].isFocused = false
    }
    tabs.append(newTab)
    currentTabIndex = tabs.count - 1
    newTab.isFocused = true
    chatService.buffer(newTab, for: newTab.id)
    saveTabState()
  }

  /// Switch to a specific tab by index
  func selectTab(at index: Int) {
    guard index >= 0, index < tabs.count else { return }
    // Unfocus the previously selected tab
    if currentTabIndex >= 0, currentTabIndex < tabs.count {
      tabs[currentTabIndex].isFocused = false
    }
    currentTabIndex = index
    // Focus the newly selected tab (which will clear the badge via didSet)
    tabs[index].isFocused = true
    saveLastOpenThreadId(tab.id)
    saveTabState()
  }

  /// Close a tab at the specified index
  func closeTab(at index: Int) {
    guard index >= 0, index < tabs.count else { return }
    guard tabs.count > 1 else {
      // Don't close the last tab, just create a new one
      let newTab = ChatThreadViewModel()
      newTab.isFocused = true
      tabs[0] = newTab
      currentTabIndex = 0
      saveTabState()
      return
    }

    tabs.remove(at: index)

    // Adjust currentTabIndex if needed
    if currentTabIndex >= tabs.count {
      currentTabIndex = tabs.count - 1
    } else if currentTabIndex > index {
      currentTabIndex -= 1
    }

    // Ensure the new current tab is focused
    tabs[currentTabIndex].isFocused = true

    saveTabState()
  }

  /// Close the currently active tab
  func closeCurrentTab() {
    closeTab(at: currentTabIndex)
  }

  // MARK: - Persistence Methods

  func loadPersistedChatThreads() async {
    do {
      // Try to load all open tabs from UserDefaults
      if let tabIdsData = userDefaults.array(forKey: Constants.openTabIdsKey) as? [String] {
        let tabIds = tabIdsData.compactMap { UUID(uuidString: $0) }
        var loadedTabs = [ChatThreadViewModel]()

        for tabId in tabIds {
          if let thread = try await chatHistoryService.loadChatThread(id: tabId) {
            let viewModel = chatService.knownObject(for: thread.id) ?? ChatThreadViewModel(from: thread)
            chatService.buffer(viewModel, for: viewModel.id)
            loadedTabs.append(viewModel)
          }
        }

        if !loadedTabs.isEmpty {
          tabs = loadedTabs
          // Restore the current tab index
          let savedIndex = userDefaults.integer(forKey: Constants.currentTabIndexKey)
          currentTabIndex = min(max(0, savedIndex), tabs.count - 1)
          // Set focus on the current tab
          tabs[currentTabIndex].isFocused = true
          return
        }
      }

      // Fallback: load the last open thread (legacy behavior)
      if let id = userDefaults.string(forKey: Constants.lastOpenChatThreadIdKey) {
        if
          let threadId = UUID(uuidString: id),
          let thread = try await chatHistoryService.loadChatThread(id: threadId)
        {
          let viewModel = chatService.knownObject(for: thread.id) ?? ChatThreadViewModel(from: thread)
          viewModel.isFocused = true
          chatService.buffer(viewModel, for: viewModel.id)
          tabs = [viewModel]
          currentTabIndex = 0
          return
        }
        userDefaults.removeObject(forKey: Constants.lastOpenChatThreadIdKey)
      }

      // Last resort: load the most recent thread
      guard
        let threadId = try await chatHistoryService.loadLastChatThreads(last: 1, offset: 0).first?.id,
        let thread = try await chatHistoryService.loadChatThread(id: threadId)
      else {
        return
      }
      let viewModel = chatService.knownObject(for: thread.id) ?? ChatThreadViewModel(from: thread)
      viewModel.isFocused = true
      chatService.buffer(viewModel, for: viewModel.id)
      tabs = [viewModel]
      currentTabIndex = 0
    } catch {
      defaultLogger.error("Failed to load chat tabs from database", error)
    }
  }

  private enum Constants {
    static let lastOpenChatThreadIdKey = "lastOpenChatThreadId"
    static let openTabIdsKey = "openChatTabIds"
    static let currentTabIndexKey = "currentChatTabIndex"
  }

  @ObservationIgnored private var cancellables = Set<AnyCancellable>()

  private let appEventHandlerRegistry: AppEventHandlerRegistry
  private let xcodeObserver: XcodeObserver
  private let fileManager: FileManagerI

  /// Save the current tab state to UserDefaults
  private func saveTabState() {
    let tabIds = tabs.map(\.id.uuidString)
    userDefaults.set(tabIds, forKey: Constants.openTabIdsKey)
    userDefaults.set(currentTabIndex, forKey: Constants.currentTabIndexKey)
    if currentTabIndex >= 0, currentTabIndex < tabs.count {
      saveLastOpenThreadId(tabs[currentTabIndex].id)
    }
  }

  private func saveLastOpenThreadId(_ threadId: UUID) {
    userDefaults.set(threadId.uuidString, forKey: Constants.lastOpenChatThreadIdKey)
  }

  private func selectChatThread(id: UUID) async {
    do {
      // Check if the thread is already open in a tab
      if let existingIndex = tabs.firstIndex(where: { $0.id == id }) {
        selectTab(at: existingIndex)
        showChatHistory = false
        return
      }

      // Load the thread and open it in a new tab
      guard let thread = try await chatHistoryService.loadChatThread(id: id) else {
        defaultLogger.error("Could not find chat thread \(id)")
        showChatHistory = false
        return
      }

      let viewModel = chatService.knownObject(for: thread.id) ?? ChatThreadViewModel(from: thread)
      // Unfocus the previously selected tab
      if currentTabIndex >= 0, currentTabIndex < tabs.count {
        tabs[currentTabIndex].isFocused = false
      }
      tabs.append(viewModel)
      currentTabIndex = tabs.count - 1
      viewModel.isFocused = true
      chatService.buffer(viewModel, for: viewModel.id)
      saveTabState()
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
        return true
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

  private func handle(addCodeToChatEvent event: AddCodeToChatEvent) async {
    if !ProcessInfo.processInfo.isRunningInTestEnvironment {
      NSApp.setActivationPolicy(.regular)
      // TODO: make sure the app is activated. Sometimes it doesn't work.
      Task { try await NSApplication.activateCurrentApp() }
    }

    if event.newThread {
      addTab()
    }
    if let chatMode = event.chatMode {
      tab.input.mode = chatMode
    }

    tab.input.textInputNeedsFocus = true

    if let workspace = xcodeObserver.state.focusedWorkspace {
      let handled = await addCodeSelection(from: workspace)
      if !handled {
        // Add log for debugging.
        if
          let axInfo = xcodeObserver.state.wrapped?.xcodesState.first?.workspaces.first?.axElement.debugDescription
        {
          defaultLogger.log(axInfo as String)
        }
      }
    } else {
      defaultLogger.log("No workspace found to handle add to code to chat event")
    }
  }

  private func addCodeSelection(from workspace: XcodeWorkspaceState) async -> Bool {
    let inputModel = tab.input
    let editor = workspace.focussedEditor
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

    guard let filePath = await xcodeObserver.focusedTabURL(in: workspace) else {
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
