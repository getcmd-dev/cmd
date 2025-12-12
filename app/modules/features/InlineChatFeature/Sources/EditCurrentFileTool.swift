// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ConcurrencyFoundation
import Dependencies
import Foundation
import JSONFoundation
import ToolFoundation

// MARK: - EditCurrentFileTool

/// A simplified tool for editing the currently focused file in inline chat.
/// Unlike the full EditFilesTool, this doesn't track known file states or handle multiple files.
final class EditCurrentFileTool: Tool {
  init(oldContent: String) {
    self.oldContent = oldContent
  }

  final class Use: ToolUse, @unchecked Sendable {
    init(
      callingTool: EditCurrentFileTool,
      toolUseId: String,
      input: Input,
      context: ToolExecutionContext,
      internalState _: InternalState? = nil,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.input = input
      self.context = context

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus?.completedOrCancelled ?? .notStarted)
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    typealias InternalState = EmptyObject

    struct Input: Codable, Sendable {
      let changes: [Change]

      struct Change: Codable, Sendable {
        let search: String
        let replace: String

        init(search: String, replace: String) {
          self.search = search
          self.replace = replace
        }
      }

      init(changes: [Change]) {
        self.changes = changes
      }
    }

    struct Output: Codable, Sendable {
      let result: String

      init(result: String) {
        self.result = result
      }
    }

    let isReadonly = false

    let callingTool: EditCurrentFileTool
    let toolUseId: String
    let input: Input
    let status: Status
    let context: ToolExecutionContext
    let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    func startExecuting() {
      updateStatus.yield(.notStarted)
      updateStatus.yield(.running)

      do {
        var content = callingTool.oldContent

        for change in input.changes {
          // Find all occurrences of the search string
          let occurrences = content.ranges(of: change.search)

          guard !occurrences.isEmpty else {
            throw AppError(
              message: "Could not find the search text in the file. Make sure to use exact text including whitespace and indentation.")
          }

          guard occurrences.count == 1 else {
            throw AppError(
              message: "Found \(occurrences.count) occurrences of the search text. The search text must be unique in the file. Provide more context to make it unique.")
          }

          // Apply the replacement
          let range = occurrences[0]
          content.replaceSubrange(range, with: change.replace)
        }
        updateStatus.complete(with: .success(.init(result: content)))
      } catch {
        updateStatus.complete(with: .failure(error))
      }
    }

    func cancel() {
      updateStatus.complete(with: .failure(CancellationError()))
    }
  }

  let oldContent: String

  let id = "edit_current_file"
  let referenceId = "edit_current_file"
  let name = "edit_current_file"

  let description = """
    Edit the currently focused file by specifying exact search and replace operations.

    Usage:
    - The SEARCH section must exactly match existing content including whitespace and indentation.
    - You can make multiple changes in a single call using multiple search/replace blocks.
    - Always try to minimize duplicate content in search/replace blocks.
    - Make all necessary changes in a single tool call when possible.

    Example:
    {
      "changes": [
        {
          "search": "import Foundation",
          "replace": "import Foundation\\nimport UIKit"
        },
        {
          "search": "func add(a: Int, b: Int) -> Int",
          "replace": "// Add two numbers\\nfunc add(a: Int, b: Int) -> Int"
        }
      ]
    }
    """

  var displayName: String {
    "Edit Current File"
  }

  var shortDescription: String {
    "Edit the currently focused file with search and replace operations."
  }

  var inputSchema: JSON {
    .object([
      "type": .string("object"),
      "properties": .object([
        "changes": .object([
          "type": .string("array"),
          "items": .object([
            "type": .string("object"),
            "properties": .object([
              "search": .object([
                "type": .string("string"),
                "description": .string("The text to search for in the file"),
              ]),
              "replace": .object([
                "type": .string("string"),
                "description": .string("The text to replace the search text with"),
              ]),
            ]),
            "required": .array([.string("search"), .string("replace")]),
          ]),
        ]),
      ]),
      "required": .array([.string("changes")]),
    ])
  }
}

extension String {
  fileprivate func ranges(of searchString: String) -> [Range<String.Index>] {
    var ranges = [Range<String.Index>]()
    var startIndex = startIndex

    while startIndex < endIndex {
      if let range = range(of: searchString, range: startIndex..<endIndex) {
        ranges.append(range)
        startIndex = range.upperBound
      } else {
        break
      }
    }

    return ranges
  }
}
