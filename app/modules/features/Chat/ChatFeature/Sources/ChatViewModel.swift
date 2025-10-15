// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppEventServiceInterface
import AppFoundation
import ChatAppEvents
import ChatCompletionServiceInterface
import ChatFoundation
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
    self.tab = tab
    self.currentModel = currentModel

    @Dependency(\.appEventHandlerRegistry) var appEventHandlerRegistry
    @Dependency(\.xcodeObserver) var xcodeObserver
    @Dependency(\.fileManager) var fileManager
    @Dependency(\.chatHistoryService) var chatHistoryService
    @Dependency(\.userDefaults) var userDefaults
    @Dependency(\.llmService) var llmService
    self.appEventHandlerRegistry = appEventHandlerRegistry
    self.xcodeObserver = xcodeObserver
    self.fileManager = fileManager
    self.chatHistoryService = chatHistoryService
    self.userDefaults = userDefaults
    self.llmService = llmService

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
  let userDefaults: UserDefaultsI
  let llmService: LLMService

  let chatHistory = ChatHistoryViewModel()

  var tab: ChatThreadViewModel {
    didSet {
      saveLastOpenThreadId(tab.id)
    }
  }

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
  func addTab(copyingCurrentInput: Bool = false, threadId: UUID? = nil) {
    let newTab = ChatThreadViewModel(id: threadId)
    let currentTab = tab
    tab = newTab
    if copyingCurrentInput {
      newTab.input = currentTab.input.copy(
        didTapSendMessage: { Task { [weak newTab] in await newTab?.sendMessage() } },
        didCancelMessage: { newTab.cancelCurrentMessage() })
    }
  }

  // MARK: - Persistence Methods

  func loadPersistedChatThreads() async {
    do {
      if let id = userDefaults.string(forKey: Constants.lastOpenChatThreadIdKey) {
        if
          let threadId = UUID(uuidString: id),
          let thread = try await chatHistoryService.loadChatThread(id: threadId)
        {
          tab = ChatThreadViewModel(from: thread)
          return
        }
        userDefaults.removeObject(forKey: Constants.lastOpenChatThreadIdKey)
      }
      guard
        let threadId = try await chatHistoryService.loadLastChatThreads(last: 1, offset: 0).first?.id,
        let thread = try await chatHistoryService.loadChatThread(id: threadId)
      else {
        return
      }
      tab = ChatThreadViewModel(from: thread)
    } catch {
      defaultLogger.error("Failed to load chat tabs from database", error)
    }
  }

  private enum Constants {
    static let lastOpenChatThreadIdKey = "lastOpenChatThreadId"
  }

  @ObservationIgnored private var cancellables = Set<AnyCancellable>()

  private let appEventHandlerRegistry: AppEventHandlerRegistry
  private let xcodeObserver: XcodeObserver
  private let fileManager: FileManagerI

  private func saveLastOpenThreadId(_ threadId: UUID) {
    userDefaults.set(threadId.uuidString, forKey: Constants.lastOpenChatThreadIdKey)
  }

  private func selectChatThread(id: UUID) async {
    do {
      guard let thread = try await chatHistoryService.loadChatThread(id: id) else {
        defaultLogger.error("Could not find chat thread \(id)")
        showChatHistory = false
        return
      }

      tab = ChatThreadViewModel(from: thread)
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

  private func addCodeSelection(from workspace: XcodeWorkspaceState) async -> Bool {
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
