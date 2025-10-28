// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Dependencies
import Foundation
import JSONFoundation
import ShellServiceInterface
import SwiftUI
import ToolFoundation
import ToolTypesFoundation

// MARK: - GlobTool

public final class GlobTool: Tool {

  public init() { }

  // TODO: remove @unchecked Sendable once https://github.com/pointfreeco/swift-dependencies/discussions/267 is fixed.
  public final class Use: ToolUse,
    @unchecked Sendable
  {
    public init(
      callingTool: GlobTool,
      toolUseId: String,
      inputResult: Result<Input, ToolDecodingError>,
      context: ToolExecutionContext,
      internalState _: InternalState? = nil,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.context = context

      let input: Input
      switch inputResult {
      case .success(let value):
        input = value
      case .failure:
        input = Input(pattern: "", path: nil)
      }

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .notStarted(input: input))
      if case .completed = stream.value { updateStatus.finish() }
      status = stream
      self.updateStatus = updateStatus
    }

    public typealias Input = ToolsSchema.GlobToolInput
    public typealias Output = ToolsSchema.GlobToolOutput

    @MainActor public lazy var viewModel: AnyToolUseViewModel = createViewModel()

    public let isReadonly = true

    public let callingTool: GlobTool
    public let toolUseId: String

    public let status: Status

    public let context: ToolExecutionContext

    public let updateStatus: AsyncStream<ToolUseExecutionStatus<Input, Output>>.Continuation

    public var input: Input? { status.value.input }

    public func startExecuting() {
      guard let input = status.value.input else { return }
      // Transition from pendingApproval to notStarted to running
      updateStatus.yield(.notStarted(input: input))
      updateStatus.yield(.running(input: input))

      guard let input = status.value.input else { return }
      guard let projectRoot = context.projectRoot else {
        updateStatus.complete(with: .failure(AppError("Cannot glob files without a project")), input: input)
        return
      }
      Task {
        do {
          let searchPath = input.path ?? projectRoot.path()

          // Convert glob pattern to find command
          // Examples:
          // "**/*.swift" -> find . -name "*.swift"
          // "src/**/*.ts" -> find src -name "*.ts"
          let pattern = input.pattern
          let namePattern: String =
            if pattern.contains("**/") {
              // Extract the file pattern after **/
              pattern.components(separatedBy: "**/").last ?? pattern
            } else if pattern.contains("/") {
              // If pattern has path components, extract the filename pattern
              (pattern as NSString).lastPathComponent
            } else {
              pattern
            }

          // Build find command - limit to 100 results
          let findCommand = "find \"\(searchPath)\" -name \"\(namePattern)\" -type f | head -100"

          let result = try await shellService.run(
            findCommand,
            cwd: projectRoot.path(),
            useInteractiveShell: false,
            env: nil)

          // Parse the output to get file paths
          let files = (result.stdout ?? "")
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

          let output = Output(files: files)
          updateStatus.complete(with: .success(output), input: input)
        } catch {
          updateStatus.complete(with: .failure(error), input: input)
        }
      }
    }

    public func receive(output: JSONFoundation.JSON.Value) throws {
      guard let input = status.value.input else { return }
      let output = try JSONDecoder().decode(Output.self, from: JSONEncoder().encode(output))
      updateStatus.complete(with: .success(output), input: input)
    }

    public func cancel() {
      guard let input = status.value.input else { return }
      updateStatus.complete(with: .failure(CancellationError()), input: input)
    }

    @Dependency(\.shellService) private var shellService

  }

  public let id = "glob"
  public let name = "glob"

  public let description = """
    Fast file pattern matching tool that works with any codebase size. Supports glob patterns like "**/*.js" or "src/**/*.ts". Returns matching file paths sorted by modification time. Use this tool when you need to find files by name patterns.
    """

  public var referenceId: String { id }

  public var displayName: String {
    "Glob"
  }

  public var shortDescription: String {
    "Find files by pattern matching using glob syntax."
  }

  public var inputSchema: JSON {
    .object([
      "type": .string("object"),
      "properties": .object([
        "pattern": .object([
          "type": .string("string"),
          "description": .string("The glob pattern to match files against"),
        ]),
        "path": .object([
          "type": .string("string"),
          "description": .string(
            "The directory to search in. If not specified, the current working directory will be used. IMPORTANT: Omit this field to use the default directory. DO NOT enter \"undefined\" or \"null\" - simply omit it for the default behavior. Must be a valid directory path if provided."),
        ]),
      ]),
      "required": .array([.string("pattern")]),
    ])
  }

}

// MARK: - GlobTool.Use + DisplayableToolUse

extension GlobTool.Use: DisplayableToolUse {
  @MainActor
  func createViewModel() -> AnyToolUseViewModel {
    AnyToolUseViewModel(GlobToolUseViewModel(
      status: status,
      input: input ?? Input(pattern: "", path: nil)))
  }
}
