// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatServiceInterface
@preconcurrency import Combine
import ConcurrencyFoundation
import Dependencies
import FileDiffFoundation
import Foundation
import FoundationInterfaces
import JSONFoundation
import LoggingServiceInterface
import SwiftUI
import ThreadSafe
import ToolFoundation

// MARK: - EditFilesTool

public final class EditFilesTool: Tool {

  public init(shouldAutoApply: Bool) {
    self.shouldAutoApply = shouldAutoApply
  }

  // TODO: remove @unchecked Sendable once https://github.com/pointfreeco/swift-dependencies/discussions/267 is fixed.
  public final class Use: UpdatableToolUse, @unchecked Sendable {
    public init(
      callingTool: EditFilesTool,
      toolUseId: String,
      input: Input,
      isInputComplete: Bool,
      context: ToolExecutionContext,
      internalState: InternalState? = nil,
      initialStatus: Status.Element?)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      _isInputComplete = Atomic(isInputComplete)
      self.context = context

      _input = Atomic(input)

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted)
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus

      let (mappedInput, error) = context.mappedInput(persistedInput: internalState?.convertedInput, rawInput: input)
      self.mappedInput = Atomic(mappedInput)

      // Initialize or update formatted output
      if let internalState {
        formattedOutput = Atomic(internalState.formattedOutput)
      } else {
        let initialOutput = FormattedOutput(
          fileChanges: mappedInput.map { fileChange in
            FileChangeInfo(
              path: fileChange.path.path,
              isNewFile: fileChange.isNewFile ?? false,
              changeCount: fileChange.changes.count,
              status: .pending)
          })
        formattedOutput = Atomic(initialOutput)
      }

      if let error, isInputComplete {
        updateStatus.complete(with: .failure(error))
      }

      if initialStatus == nil {
        // New tool use, save chat state
        chatContextRegistry.persist(thread: context.threadId)
      }
    }

    public struct InternalState: Codable, Sendable {
      let convertedInput: [FileChange]
      let formattedOutput: FormattedOutput

      public init(convertedInput: [FileChange], formattedOutput: FormattedOutput) {
        self.convertedInput = convertedInput
        self.formattedOutput = formattedOutput
      }
    }

    public struct FormattedOutput: Codable, Sendable {
      let fileChanges: [FileChangeInfo]

      public init(fileChanges: [FileChangeInfo]) {
        self.fileChanges = fileChanges
      }
    }

    public enum FileChangeStatus: Codable, Sendable {
      case pending
      case rejected
      case error(_ error: AppError)
      case applied
    }

    public struct FileChangeInfo: Codable, Sendable {
      let path: String
      let isNewFile: Bool
      let changeCount: Int
      let status: FileChangeStatus

      public init(path: String, isNewFile: Bool, changeCount: Int, status: FileChangeStatus) {
        self.path = path
        self.isNewFile = isNewFile
        self.changeCount = changeCount
        self.status = status
      }
    }

    /// Similar to `Input.FileChange` but with added computed properties that need to be persisted.
    public struct FileChange: Codable, Sendable {

      let path: URL
      let isNewFile: Bool?
      let changes: [Input.FileChange.Change]
      /// Baseline content is a property set locally, not sent by the LLM.
      /// It is used to help persist the content of the file before applying changes, so that the change is correctly displayed even after the file has changed.
      var baseLineContent: String?
      /// When an external tool provides an input that is not consistent without our state, for instance the search/replace cannot be applied to our last known content,
      /// `correctedChanges` is created to help always be able to show a diff.
      /// The corrected diff is created to match the change between our last know content and the current content. This ensures that we can create a matching diff.
      var correctedChanges: [Input.FileChange.Change]?
    }

    public struct Input: Codable, Sendable {
      init(files: [FileChange]) {
        self.files = files
      }

      public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: String.self)
        files = try container.decode([FileChange].self, forKey: "files")
      }

      public struct FileChange: Codable, Sendable {
        public struct Change: Codable, Sendable {
          public let search: String
          public let replace: String

          public init(search: String, replace: String) {
            self.search = search
            self.replace = replace
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: String.self)
            // Decode with default values, since when streaming not all keys may be present.
            search = (try? container.decode(String.self, forKey: "search")) ?? ""
            replace = (try? container.decode(String.self, forKey: "replace")) ?? ""
          }
        }

        public let path: String
        public let isNewFile: Bool?
        public let changes: [Change]
      }

      public fileprivate(set) var files: [FileChange]

      public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: String.self)
        try container.encode(files, forKey: "files")
      }

    }

    public typealias Output = String

    @MainActor public lazy var viewModel: AnyToolUseViewModel = createViewModel()

    public let isReadonly = false

    public let callingTool: EditFilesTool
    public let toolUseId: String
    public let status: Status
    public let context: ToolExecutionContext

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    public var input: Input { _input.value }

    public var isInputComplete: Bool { _isInputComplete.value }

    public var internalState: InternalState? {
      resolvedInput
    }

    public func receive(inputUpdate data: Data, isLast: Bool) throws {
      let input = try JSONDecoder().decode(Input.self, from: data)
      _input.set(to: input)
      _isInputComplete.set(to: isLast)

      let (mappedInput, error) = context.mappedInput(persistedInput: nil, rawInput: input)
      self.mappedInput.set(to: mappedInput)
      // Update formatted output with new input
      let updatedOutput = FormattedOutput(
        fileChanges: mappedInput.map { fileChange in
          FileChangeInfo(
            path: fileChange.path.path,
            isNewFile: fileChange.isNewFile ?? false,
            changeCount: fileChange.changes.count,
            status: .pending)
        })
      formattedOutput.set(to: updatedOutput)
      if let error, isLast {
        updateStatus.complete(with: .failure(error))
      }

      Task { @MainActor in
        self._viewModel?.input = self.mappedInput.value
        self._viewModel?.isInputComplete = isLast
        self._viewModel?.toolUseResult = self.formattedOutput.value
      }
      chatContextRegistry.persist(thread: context.threadId)
    }

    public func startExecuting() {
      if case .completed = status.value {
        // Already completed (likely failed due to bad input).
        return
      }
      updateStatus.yield(.notStarted)
      updateStatus.yield(.running)
      guard _isInputComplete.value else {
        updateStatus.complete(with: .failure(AppError("Started executing before the input was entirely received")))
        return
      }

      Task { @MainActor in
        do {
          if callingTool.shouldAutoApply {
            // Apply the changes.
            await editViewModel.applyAllChanges()
          } else {
            // Wait for the user to accept the changes.
            editViewModel.acknowledgeSuggestionReceived()
          }
        }
      }
    }

    public func cancel() {
      updateStatus.complete(with: .failure(CancellationError()))
    }

    let _isInputComplete: Atomic<Bool>

    var resolvedInput: InternalState {
      InternalState(
        convertedInput: mappedInput.value,
        formattedOutput: formattedOutput.value)
    }

    @MainActor
    var editViewModel: EditFilesToolUseViewModel {
      if let _viewModel {
        return _viewModel
      }
      let viewModel = EditFilesToolUseViewModel(
        status: status,
        input: mappedInput.value,
        isInputComplete: isInputComplete,
        setResult: { [weak self, mappedInput, context] toolUseResult in
          // TODO: Rework the output sent to the LLM and add tests
          guard let self else { return }
          if
            isInputComplete,
            toolUseResult.fileChanges.contains(where: { if case .error = $0.status { true } else { false } }) ||
            toolUseResult.fileChanges.allSatisfy({ if case .applied = $0.status { true } else { false } })
          {
            // If one change failed to apply, or all were successfully applied, complete the tool use.
            updateStatus.yield(.completed(toolUseResult.asToolUseResult))
          }
          // Update tracked content for successfully applied files
          context.updateFilesContent(changes: toolUseResult.fileChanges, input: mappedInput.value)
        },
        toolUseResult: formattedOutput.value,
        projectRoot: context.projectRoot)
      _viewModel = viewModel
      return viewModel
    }

    @Dependency(\.chatContextRegistry) private var chatContextRegistry

    private let _input: Atomic<Input>
    private let mappedInput: Atomic<[FileChange]>
    private let formattedOutput: Atomic<FormattedOutput>

    @MainActor private var _viewModel: EditFilesToolUseViewModel?
  }

  public let inputSchema: JSON =
    try! JSONDecoder().decode(JSON.self, from: """
      {
        "type": "object",
        "properties": {
          "files": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "path": {
                  "type": "string",
                  "description": "The path of the file to modify. It should be relative to the project root."
                },
                "isNewFile": {
                  "type": "boolean",
                  "description": "Whether a new file should be created. In this case, and only in this case `search` should be an empty string."
                },
                "changes": {
                  "type": "array",
                  "items": {
                    "type": "object",
                    "properties": {
                      "search": {
                        "type": "string",
                        "description": "The text to search for in the file"
                      },
                      "replace": {
                        "type": "string",
                        "description": "The text to replace the search text with"
                      }
                    },
                    "required": ["search", "replace"]
                  }
                }
              },
              "required": ["path", "changes"]
            }
          }
        },
        "required": ["files"]
      }
      """.utf8Data)

  public let canInputBeStreamed = true

  public var name: String {
    if shouldAutoApply {
      "edit_or_create_files"
    } else {
      "suggest_files_changes"
    }
  }

  public var displayName: String {
    "Edit Files"
  }

  public var description: String { """
    \(shortDescription)
    This tool allows for precise, surgical replaces to files by specifying exactly what content to search for and what to replace it with.
    The tool will maintain proper indentation and formatting while making changes.

    The SEARCH section must exactly match existing content including whitespace and indentation.
    If you're not confident in the exact content to search for, use the read_file tool first to get the exact content.
    When applying the diffs, be extra careful to remember to change any closing brackets or other syntax that may be affected by the diff farther down in the file.
    ALWAYS make as many changes in a single 'apply_diff' request as possible using multiple SEARCH/REPLACE blocks.
    ALWAYS try to minimize duplicate content in search/replace block and use several blocks instead when possible.
    ONLY modify files that have already been read. If a file you want to modify has not been read yet, use the read_file tool first to read it.

    example:

    Good example:
    - uses relative paths.
    - updates several files at once.
    - break down changes in one file into several blocks when possible.
    ```
    {
        "files": [
            {
                "path": "./Sources/MyFile.swift",
                "changes": [
                    {
                        "search": "import Foundation",
                        "replace": "import Foundation\nimport UIKit"
                    },
                    {
                        "search": "func add(a: Int, b: Int) -> Int",
                        "replace": "// Add two numbers\nfunc add(a: Int, b: Int) -> Int"
                    }
                ]
            },
            {
                "path": "./Tests/MyFileTests.swift",
                "changes": [
                    {
                        "search": "import XCTest",
                        "replace": "import Testing"
                    }
                ]
            }
        ]
    ```
    """
  }

  public var shortDescription: String {
    if shouldAutoApply {
      "Update existing code or create new files."
    } else {
      "Suggest updates to existing code, or to create new files."
    }
  }

  public func isAvailable(in mode: ChatMode) -> Bool {
    switch mode {
    case .agent:
      shouldAutoApply
    case .ask:
      !shouldAutoApply
    }
  }

  private let shouldAutoApply: Bool

}

// MARK: - EditFilesTool.Use + DisplayableToolUse

extension EditFilesTool.Use: DisplayableToolUse {

  @MainActor
  func createViewModel() -> AnyToolUseViewModel {
    AnyToolUseViewModel(editViewModel)
  }
}

extension ChatContextRegistryService {
  func persist(thread id: String) {
    do {
      try context(for: id).requestPersistence()
    } catch {
      defaultLogger.error("Failed to persist thread")
    }
  }
}
