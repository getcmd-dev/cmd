// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import JSONFoundation
import LocalServerServiceInterface
import LoggingServiceInterface
import SwiftUI
import ToolFoundation

// MARK: - ClaudeCodeGrepTool

public final class ClaudeCodeGrepTool: ExternalTool {

  public init() { }

  // TODO: remove @unchecked Sendable once https://github.com/pointfreeco/swift-dependencies/discussions/267 is fixed.
  public final class Use: ExternalToolUse, @unchecked Sendable {
    public init(
      callingTool: ClaudeCodeGrepTool,
      toolUseId: String,
      input: Input,
      context: ToolExecutionContext,
      internalState _: InternalState? = nil,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.context = context

      var input = input
      input.projectRoot = input.projectRoot ?? context.projectRoot?.path
      self.input = input

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted)
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    public typealias InternalState = EmptyObject

    public typealias Input = ClaudeCodeGrepInput

    public typealias Output = SearchFilesTool.Use.Output

    public let isReadonly = true

    public let callingTool: ClaudeCodeGrepTool
    public let toolUseId: String
    public let input: Input

    public let status: Status

    public let context: ToolExecutionContext

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

    public func receive(output: String) throws {
      // Try parsing with the simple format first
      if let result = parseSimpleGrepOutput(rawOutput: output, projectRoot: input.projectRoot) {
        updateStatus.complete(with: .success(result))
        return
      }

      // If that fails, try parsing with context format
      if let result = parseGrepOutputWithContext(rawOutput: output, projectRoot: input.projectRoot) {
        updateStatus.complete(with: .success(result))
        return
      }

      // If both fail, return the raw output
      defaultLogger.error("Could not parse output for Claude Code Grep: \(output)")
      updateStatus.complete(with: .success(Output(
        outputForLLm: output,
        results: [],
        rootPath: input.projectRoot ?? "/",
        hasMore: false)))
    }

  }

  public let name = "claude_code_Grep"

  public let description = """
    A powerful search tool built on ripgrep

    Usage:
    - ALWAYS use Grep for search tasks. NEVER invoke `grep` or `rg` as a Bash command. The Grep tool has been optimized for correct permissions and access.
    - Supports full regex syntax (e.g., "log.*Error", "function\\s+\\w+")
    - Filter files with glob parameter (e.g., "*.js", "**/*.tsx") or type parameter (e.g., "js", "py", "rust")
    - Output modes: "content" shows matching lines, "files_with_matches" shows only file paths (default), "count" shows match counts
    - Use Task tool for open-ended searches requiring multiple rounds
    - Pattern syntax: Uses ripgrep (not grep) - literal braces need escaping (use `interface\\{\\}` to find `interface{}` in Go code)
    - Multiline matching: By default patterns match within single lines only. For cross-line patterns like `struct \\{[\\s\\S]*?field`, use `multiline: true`
    """

  public var displayName: String {
    "Grep"
  }

  public var shortDescription: String {
    "Powerful regex search tool built on ripgrep for finding patterns in files."
  }

  public var inputSchema: JSON {
    .object([
      "type": .string("object"),
      "properties": .object([
        "pattern": .object([
          "type": .string("string"),
          "description": .string("The regular expression pattern to search for in file contents"),
        ]),
        "path": .object([
          "type": .string("string"),
          "description": .string("File or directory to search in (rg PATH). Defaults to current working directory."),
        ]),
        "glob": .object([
          "type": .string("string"),
          "description": .string("Glob pattern to filter files (e.g. \"*.js\", \"*.{ts,tsx}\") - maps to rg --glob"),
        ]),
        "output_mode": .object([
          "type": .string("string"),
          "enum": .array([.string("content"), .string("files_with_matches"), .string("count")]),
          "description": .string(
            "Output mode: \"content\" shows matching lines (supports -A/-B/-C context, -n line numbers, head_limit), \"files_with_matches\" shows file paths (supports head_limit), \"count\" shows match counts (supports head_limit). Defaults to \"files_with_matches\"."),
        ]),
        "-B": .object([
          "type": .string("number"),
          "description": .string(
            "Number of lines to show before each match (rg -B). Requires output_mode: \"content\", ignored otherwise."),
        ]),
        "-A": .object([
          "type": .string("number"),
          "description": .string(
            "Number of lines to show after each match (rg -A). Requires output_mode: \"content\", ignored otherwise."),
        ]),
        "-C": .object([
          "type": .string("number"),
          "description": .string(
            "Number of lines to show before and after each match (rg -C). Requires output_mode: \"content\", ignored otherwise."),
        ]),
        "-n": .object([
          "type": .string("boolean"),
          "description": .string("Show line numbers in output (rg -n). Requires output_mode: \"content\", ignored otherwise."),
        ]),
        "-i": .object([
          "type": .string("boolean"),
          "description": .string("Case insensitive search (rg -i)"),
        ]),
        "type": .object([
          "type": .string("string"),
          "description": .string(
            "File type to search (rg --type). Common types: js, py, rust, go, java, etc. More efficient than include for standard file types."),
        ]),
        "head_limit": .object([
          "type": .string("number"),
          "description": .string(
            "Limit output to first N lines/entries, equivalent to \"| head -N\". Works across all output modes: content (limits output lines), files_with_matches (limits file paths), count (limits count entries). When unspecified, shows all results from ripgrep."),
        ]),
        "multiline": .object([
          "type": .string("boolean"),
          "description": .string(
            "Enable multiline mode where . matches newlines and patterns can span lines (rg -U --multiline-dotall). Default: false."),
        ]),
      ]),
      "required": .array([.string("pattern")]),
    ])
  }

  public func isAvailable(in _: ChatMode) -> Bool {
    true
  }

}

// MARK: - ClaudeCodeGrepInput

public struct ClaudeCodeGrepInput: Codable, Sendable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    pattern = try container.decode(String.self, forKey: .pattern)
    path = try container.decodeIfPresent(String.self, forKey: .path)
    glob = try container.decodeIfPresent(String.self, forKey: .glob)
    outputMode = try container.decodeIfPresent(String.self, forKey: .outputMode)
    beforeContext = try container.decodeIfPresent(Int.self, forKey: .beforeContext)
    afterContext = try container.decodeIfPresent(Int.self, forKey: .afterContext)
    contextLines = try container.decodeIfPresent(Int.self, forKey: .contextLines)
    lineNumbers = try container.decodeIfPresent(Bool.self, forKey: .lineNumbers)
    caseInsensitive = try container.decodeIfPresent(Bool.self, forKey: .caseInsensitive)
    type = try container.decodeIfPresent(String.self, forKey: .type)
    headLimit = try container.decodeIfPresent(Int.self, forKey: .headLimit)
    multiline = try container.decodeIfPresent(Bool.self, forKey: .multiline)
    projectRoot = try container.decodeIfPresent(String.self, forKey: .projectRoot)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(pattern, forKey: .pattern)
    try container.encodeIfPresent(path, forKey: .path)
    try container.encodeIfPresent(glob, forKey: .glob)
    try container.encodeIfPresent(outputMode, forKey: .outputMode)
    try container.encodeIfPresent(beforeContext, forKey: .beforeContext)
    try container.encodeIfPresent(afterContext, forKey: .afterContext)
    try container.encodeIfPresent(contextLines, forKey: .contextLines)
    try container.encodeIfPresent(lineNumbers, forKey: .lineNumbers)
    try container.encodeIfPresent(caseInsensitive, forKey: .caseInsensitive)
    try container.encodeIfPresent(type, forKey: .type)
    try container.encodeIfPresent(headLimit, forKey: .headLimit)
    try container.encodeIfPresent(multiline, forKey: .multiline)
    try container.encodeIfPresent(projectRoot, forKey: .projectRoot)
  }

  enum CodingKeys: String, CodingKey {
    case pattern
    case path
    case glob
    case outputMode = "output_mode"
    case beforeContext = "-B"
    case afterContext = "-A"
    case contextLines = "-C"
    case lineNumbers = "-n"
    case caseInsensitive = "-i"
    case type
    case headLimit = "head_limit"
    case multiline
    case projectRoot
  }

  let pattern: String
  let path: String?
  let glob: String?
  let outputMode: String?
  let beforeContext: Int?
  let afterContext: Int?
  let contextLines: Int?
  let lineNumbers: Bool?
  let caseInsensitive: Bool?
  let type: String?
  let headLimit: Int?
  let multiline: Bool?

  /// Additional property used internally for server request
  var projectRoot: String?

}

// MARK: - Parsing Functions

/// Parse the simple Grep output from Claude Code
/// The output is in a simple format showing file paths, like:
/// ```
/// Found 2 files
/// /Users/me/cmd/app/modules/serviceInterfaces/LocalServerServiceInterface/Sources/sendMessageSchema.generated.swift
/// /Users/me/cmd/app/modules/services/ChatHistoryService/Sources/Serialization.swift
/// ```
private func parseSimpleGrepOutput(rawOutput: String, projectRoot: String?) -> Schema.SearchFilesToolOutput? {
  // Check if output starts with "Found X files"
  let foundFilesRegex = #/^Found \d+ files?\n/#
  guard rawOutput.starts(with: foundFilesRegex) else {
    return nil
  }

  // Extract file paths (each on its own line after the header)
  let lines = rawOutput.split(separator: "\n").dropFirst() // Skip "Found X files" line
  let filePaths = lines.compactMap { line -> String? in
    guard !line.isEmpty else { return nil }
    return String(line)
  }

  return Schema.SearchFilesToolOutput(
    outputForLLm: rawOutput,
    results: filePaths.map { .init(path: $0, searchResults: []) },
    rootPath: projectRoot ?? "/",
    hasMore: false)
}

/// Parse the Grep output with context from Claude Code
/// The output is in a format showing file paths with line numbers and context, like:
/// ```
/// /path/to/file.swift-152-      input: mappedInput,
/// /path/to/file.swift-153-      isInputComplete: true,
/// /path/to/file.swift:154:      setResult: { _ in },
/// /path/to/file.swift-155-      context: context)
/// --
/// /path/to/another.swift-30-    input: [EditFilesTool.Use.FileChange],
/// ```
private func parseGrepOutputWithContext(rawOutput: String, projectRoot: String?) -> Schema.SearchFilesToolOutput? {
  // Regex patterns for matched and context lines
  let matchedLineRegex = #/^(?<path>.+):(?<lineNum>\d+):(?<text>.*)$/#

  var fileResults: [String: [Schema.SearchResult]] = [:]
  var fileOrder: [String] = []

  for line in rawOutput.split(separator: "\n") {
    // Skip separator lines
    if line == "--" || line.isEmpty {
      continue
    }

    // Try to match as a matched line (with colons)
    if let match = try? matchedLineRegex.wholeMatch(in: line) {
      let path = String(match.path)
      if let lineNum = Int(match.lineNum) {
        if fileResults[path] == nil {
          fileOrder.append(path)
          fileResults[path] = []
        }
        fileResults[path]?.append(Schema.SearchResult(
          line: lineNum,
          text: String(match.text),
          isMatch: true))
      }
    }
  }

  if fileResults.isEmpty {
    return nil
  }

  // Convert to output format
  let results = fileOrder.map { path in
    Schema.SearchFileResult(
      path: path,
      searchResults: fileResults[path] ?? [])
  }

  return Schema.SearchFilesToolOutput(
    outputForLLm: rawOutput,
    results: results,
    rootPath: projectRoot ?? "/",
    hasMore: false)
}

// MARK: - ClaudeCodeGrepTool.Use + DisplayableToolUse

extension ClaudeCodeGrepTool.Use: DisplayableToolUse {
  public var viewModel: AnyToolUseViewModel {
    let mappedInput = SearchFilesTool.Use.Input(
      directoryPath: input.path ?? input.projectRoot ?? "/",
      regex: input.pattern,
      filePattern: input.glob)
    return AnyToolUseViewModel(ToolUseViewModel(status: status, input: mappedInput))
  }
}
