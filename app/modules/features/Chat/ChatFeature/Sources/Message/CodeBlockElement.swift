// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import CodePreview
import Combine
import ConcurrencyFoundation
import Dependencies
import FileDiffFoundation
import Foundation
import FoundationInterfaces
import HighlighterServiceInterface
import LoggingServiceInterface
import Observation

// MARK: - CodeBlockElement

/// Represents a code block in a message.
/// This can either be a standalone code block, or a diff representing a change to apply to a given file.
@Observable @MainActor
class CodeBlockElement {

  init(projectRoot: URL?, rawContent: String, isComplete: Bool, id: Int) {
    self.projectRoot = projectRoot
    self.id = id
    let content = rawContent.trimmed(isComplete: isComplete)
    _content = content
    _rawContent = content
    self.isComplete = isComplete

    highlightingTasks.sink { @Sendable highlightedText in
      Task {
        @MainActor [weak self] in
        self?.highlightedText = highlightedText
      }
    }.store(in: &cancellables)

    handleIsCompletedChanged()
  }

  let id: Int
  var language: String?
  private(set) var content: String
  private(set) var highlightedText: AttributedString?
  private(set) var isComplete: Bool

  private(set) var copyableContent: String?

  var fileChange: FileDiffViewModel?

  var filePath: String? {
    didSet {
      // Make sure the path is resolved to an absolute path
      if let filePath {
        let resolvedPath = filePath.resolvePath(from: projectRoot).path()
        if resolvedPath != filePath {
          self.filePath = resolvedPath
        }
      }
    }
  }

  private(set) var rawContent: String {
    didSet {
      content = rawContent
    }
  }

  func set(rawContent: String, isComplete: Bool) {
    self.isComplete = isComplete
    self.rawContent = rawContent.trimmed(isComplete: isComplete)

    let highlighter = highlighter
    let language: HighlightLanguage = (language.map { HighlightLanguage(rawValue: $0) } ?? nil) ?? .swift
    let content = content
    highlightingTasks.queue {
      try await highlighter.attributedText(content, language: language, colors: .codeHighlight)
    }

    handleIsCompletedChanged()
  }

  private let projectRoot: URL?

  @ObservationIgnored
  @Dependency(\.fileManager) private var fileManager
  @ObservationIgnored
  @Dependency(\.highlighter) private var highlighter

  private let highlightingTasks = ReplaceableTaskQueue<AttributedString>()
  private var cancellables = Set<AnyCancellable>()

  @MainActor
  private func handleIsCompletedChanged() {
    guard isComplete else {
      return
    }
    guard let filePath else {
      // Not a diff / new file.
      copyableContent = rawContent
      return
    }

    guard FileDiff.isLLMDiff(rawContent) else {
      // This is a new file.
      copyableContent = rawContent
      return
    }
    let diff = rawContent
    Task { [weak self] in
      do {
        let fileChange = try FileDiffViewModel(filePath: filePath, llmDiff: diff)

        self?.fileChange = fileChange
        self?.copyableContent = await fileChange.targetContent
      } catch {
        defaultLogger.error("Could not parse code change for CodeBlockElement", error)
      }
    }
  }

}
