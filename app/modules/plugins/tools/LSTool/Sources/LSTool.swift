// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import Dependencies
import Foundation
import JSONFoundation
import ServerServiceInterface
import ToolFoundation

// MARK: - LSTool

public final class LSTool: NonStreamableTool {

  public init() { }

  // TODO: remove @unchecked Sendable once https://github.com/pointfreeco/swift-dependencies/discussions/267 is fixed.
  public final class Use: ToolUse, @unchecked Sendable {
    init(
      callingTool: LSTool,
      toolUseId: String,
      input: Input,
      context: ToolExecutionContext,
      initialStatus: Status.Element? = nil)
    {
      self.callingTool = callingTool
      self.toolUseId = toolUseId
      self.context = context
      self.input = Input(
        path: input.path.resolvePath(from: context.projectRoot).path(),
        recursive: input.recursive)
      directoryPath = URL(fileURLWithPath: self.input.path)

      let (stream, updateStatus) = Status.makeStream(initial: initialStatus ?? .pendingApproval)
      status = stream
      self.updateStatus = updateStatus
    }

    public struct Input: Codable, Sendable {
      public let path: String
      public let recursive: Bool?
    }

    public struct Output: Codable, Sendable {
      public let files: [File]
      /// Whether the output was truncated because there are too many files to reasonably return.
      public let hasMore: Bool
      public struct File: Codable, Sendable {
        /// The full path of the file
        public let path: String
        /// The attributes of the file, e.g. like `drwxr-xr-x`.
        public let attr: String
        /// The size of the file in human-readable format.
        public let size: String
      }
    }

    public let isReadonly = true

    public let callingTool: LSTool
    public let toolUseId: String
    public let input: Input

    public let status: Status

    public func startExecuting() {
      // Transition from pendingApproval to notStarted to running
      updateStatus.yield(.notStarted)
      updateStatus.yield(.running)

      guard let projectRoot = context.projectRoot else {
        updateStatus.yield(.completed(.failure(AppError("Cannot list files without a project"))))
        return
      }
      Task {
        do {
          let fullInput = Schema.ListFilesToolInput(
            projectRoot: projectRoot.path(),
            path: input.path,
            recursive: input.recursive)

          let data = try JSONEncoder().encode(fullInput)
          let response: Schema.ListFilesToolOutput = try await server.postRequest(path: "listFiles", data: data)
          updateStatus.yield(.completed(.success(response.transformed(with: context))))
        } catch {
          updateStatus.yield(.completed(.failure(error)))
        }
      }
    }

    public func reject(reason: String?) {
      updateStatus.yield(.approvalRejected(reason: reason))
    }

    public func cancel() {
      updateStatus.yield(.completed(.failure(CancellationError())))
    }

    let directoryPath: URL

    let context: ToolExecutionContext

    @Dependency(\.server) private var server

    private let updateStatus: AsyncStream<ToolUseExecutionStatus<Output>>.Continuation

  }

  public let name = "list_files"

  public let description = """
    Request to list files and directories within the specified directory. If recursive is true, it will list all files and directories recursively. If recursive is false or not provided, it will only list the top-level contents.
    """

  public var displayName: String {
    "List Files"
  }

  public var shortDescription: String {
    "Lists files and directories within a specified directory, optionally recursive."
  }

  public var inputSchema: JSON {
    .object([
      "type": .string("object"),
      "properties": .object([
        "path": .object([
          "type": .string("string"),
          "description": .string(
            "The directory path to list. If the absolute path is known it should be used. Otherwise use a relative path."),
        ]),
        "recursive": .object([
          "type": .string("boolean"),
          "description": .string("Whether to list files recursively in subdirectories. Default is false."),
        ]),
      ]),
      "required": .array([.string("path")]),
    ])
  }

  public func isAvailable(in _: ChatMode) -> Bool {
    true
  }

  public func use(toolUseId: String, input: Use.Input, context: ToolExecutionContext) -> Use {
    Use(callingTool: self, toolUseId: toolUseId, input: input, context: context)
  }

}

// MARK: - ToolUseViewModel

@Observable
@MainActor
final class ToolUseViewModel {

  init(status: LSTool.Use.Status, directoryPath: URL) {
    self.status = status.value
    self.directoryPath = directoryPath
    Task {
      for await status in status {
        self.status = status
      }
    }
  }

  let directoryPath: URL
  var status: ToolUseExecutionStatus<LSTool.Use.Output>
}

extension Schema.ListFilesToolOutput {
  func transformed(with context: ToolExecutionContext) -> LSTool.Use.Output {
    .init(
      files: files.map { file in
        .init(
          path: file.path.resolvePath(from: context.projectRoot).path(),
          attr: file.permissions,
          size: ByteCountFormatter.string(fromByteCount: Int64(file.byteSize), countStyle: .file))
      }, hasMore: files.contains(where: { $0.hasMoreContent == true }))
  }
}
