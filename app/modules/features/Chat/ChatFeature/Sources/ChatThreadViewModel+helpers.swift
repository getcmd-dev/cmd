// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatFeatureInterface
import ConcurrencyFoundation
import Dependencies
import Foundation
import JSONFoundation
import LLMServiceInterface
import LocalServerServiceInterface
import LoggingServiceInterface
import ShellServiceInterface
import ToolFoundation
import XcodeObserverServiceInterface

extension ChatThreadViewModel {

  /// Converts a flat list of file information into a hierarchical string representation.
  ///
  /// This function takes an array of file paths and organizes them into a tree-like structure
  /// with proper indentation to show directory hierarchy. Files are sorted alphabetically
  /// and directories are created as needed to maintain the hierarchy.
  ///
  /// - Parameters:
  ///   - filesInfo: Array of file information containing paths and file/directory flags
  ///   - projectRoot: The root URL of the project used as the base for relative paths
  /// - Returns: A formatted string with hierarchical file structure using dashes and indentation
  /// Example:
  ///
  /// "/project/src/"
  /// "/project/src/utils/"
  /// "/project/tests/"
  ///
  /// with root project /project becomes:
  ///
  /// - ./
  ///   - src/
  ///     - utils/
  ///   - tests/
  nonisolated static func formatFileListAsHierarchy(filesInfo: [Schema.ListedFileInfo], projectRoot: URL) -> String {
    let filesInfo = filesInfo
      .sorted { $0.path < $1.path }
    var result: [String] = []
    var indentation: [String] = []
    var processedPaths = Set<String>()

    let dirInfoMap = Dictionary(uniqueKeysWithValues: filesInfo.filter { !$0.isFile }.map { ($0.path, $0) })

    var processDir: (URL, URL) -> Void = { _, _ in }
    processDir = { dir, projectRoot in
      if !dir.path.hasPrefix(projectRoot.path) {
        // Bad data.
        return
      }
      // Handle intermediate directories, in case they are missing from the input.
      if let lastDirPath = indentation.last, dir.path != lastDirPath, dir.path.starts(with: lastDirPath) {
        let parentDir = dir.deletingLastPathComponent()
        if parentDir.path != projectRoot.path {
          processDir(parentDir, projectRoot)
        }
      }

      // pop indentation until we find the containing directory
      while let previous = indentation.last, !dir.path.hasPrefix(previous) {
        indentation.removeLast()
      }

      guard !processedPaths.contains(dir.path) else { return }

      // Add the directory to the result.
      let containingDir = indentation.last ?? projectRoot.path
      var relativeDirPath = dir.path.replacingOccurrences(of: containingDir, with: "")
      if relativeDirPath.starts(with: "/") { relativeDirPath.removeFirst() }
      if relativeDirPath.isEmpty { relativeDirPath = "." }
      relativeDirPath += "/"

      let hasMoreContent = (dirInfoMap[dir.path] ?? dirInfoMap[dir.path + "/"])?.hasMoreContent == true
      result
        .append(String(repeating: "  ", count: indentation.count) + "- " + relativeDirPath +
          (hasMoreContent ? " (truncated)" : ""))
      indentation.append(dir.path)
      processedPaths.insert(dir.path)
    }

    let processFile: (URL, URL) -> Void = { file, projectRoot in
      if !file.path.hasPrefix(projectRoot.path) {
        // Bad data.
        return
      }
      let dir = file.deletingLastPathComponent()
      processDir(dir, projectRoot)

      let fileName = file.lastPathComponent
      result.append(String(repeating: "  ", count: indentation.count) + "- " + fileName)
    }
    processDir(projectRoot, projectRoot)

    for fileInfo in filesInfo {
      let path = URL(filePath: fileInfo.path)
      if fileInfo.isFile {
        processFile(path, projectRoot)
      } else {
        processDir(path, projectRoot)
      }
    }

    return result.joined(separator: "\n")
  }

  func createContextMessage(for workspace: XcodeWorkspaceState, projectRoot: URL) async throws -> ChatMessageTextContent {
    @Dependency(\.localServer) var server
    @Dependency(\.shellService) var _shellService
    let shellService: ShellService = _shellService // Necessary to deal with Swift concurrency errors.

    // Get a few of the files in the project (BFS).
    let fileLimit = 200
    let data = try JSONEncoder().encode(Schema.ListFilesToolInput(
      projectRoot: projectRoot.path,
      path: "",
      recursive: true,
      breadthFirstSearch: true,
      limit: fileLimit))

    async let response: Schema.ListFilesToolOutput = server.postRequest(path: "listFiles", data: data)

    // System info
    async let macOSVersion = shellService.run("sw_vers -productVersion")
    async let defaultXcodeVersion = shellService.run("xcodebuild -version")
    async let whichXcpretty = shellService.run("which xcpretty", useInteractiveShell: true)
    async let swiftVersion = shellService.run("swift --version")
    let structuredOutput = try await Self.formatFileListAsHierarchy(filesInfo: response.files, projectRoot: projectRoot)
    let hasXcPretty = await (try? whichXcpretty.exitCode) == 0

    let text = await """
      ### System Information:
        * macOS Version: \((try? macOSVersion)?.stdout ?? "unkonwn")
        * Default Xcode Version: \((try? defaultXcodeVersion.stdout)?.split(separator: "\n").first ?? "unknown")
        * Swift Version: \((try? swiftVersion.stdout)?.split(separator: "\n")
      .first ?? "unknown")\(hasXcPretty
      ? "\n  * xcpretty is installed. Make sure to use it when relevant to improve build outputs"
      : "")
        * Current Workspace Directory: \(workspace.url.path)
        * Project root (root of all relative path): \(projectRoot.path)
        * Files (first \(fileLimit)):
      \(structuredOutput)
      """
    return .init(projectRoot: projectRoot, text: text)
  }

}

// MARK: - State domain to API domain

extension MessageRole {
  var apiFormat: Schema.Message.Role {
    switch self {
    case .assistant:
      .assistant
    case .user:
      .user
    case .system:
      .system
    case .tool:
      .tool
    }
  }
}

extension [ChatMessageViewModel] {
  /// Converts the content to the API format.
  @MainActor
  var apiFormat: [Schema.Message] {
    let lastSummaryIdx = lastIndex(where: { message in
      if case .conversationSummary = message.content.first {
        return true
      }
      return false
    })

    return suffix(from: lastSummaryIdx ?? 0).flatMap(\.apiFormat)
  }
}

extension ChatMessageViewModel {
  /// Converts the content to the API format.
  /// When the content contains a tool use, it will be split across a message from the assistant and a message from the user, hence the array result.
  @MainActor
  fileprivate var apiFormat: [Schema.Message] {
    var messages = [Schema.Message]()
    var currentMessage = Schema.Message(role: role.apiFormat, content: [])
    for (role, messageContent) in content.flatMap(\.apiFormat) {
      if role != currentMessage.role {
        messages.append(currentMessage)
        currentMessage = Schema.Message(role: role ?? self.role.apiFormat, content: [])
      }
      currentMessage = Schema.Message(
        role: currentMessage.role,
        content: currentMessage.content + [messageContent])
    }
    messages.append(currentMessage)
    return messages
  }
}

extension ChatMessageContent {
  /// Converts the content to the API format.
  /// When the content contains a tool use, it will be split across a message from the assistant and a message from the user, hence the array result.
  @MainActor
  fileprivate var apiFormat: [(Schema.Message.Role?, Schema.MessageContent)] {
    switch self {
    case .text(let message):
      return [(nil, .textMessage(.init(
        text: message.text,
        attachments: message.attachments.map(\.apiFormat))))]

    case .nonUserFacingText(let message):
      return [(nil, .textMessage(.init(text: message.text)))]

    case .reasoning(let message):
      return [(nil, .reasoningMessage(.init(text: message.text, signature: message.signature)))]

    case .toolUse(let toolUse):
      do {
        let toolResult: Schema.ToolResultMessage.Result = {
          do {
            guard let output = try toolUse.toolUse.currentOutput else {
              // The tool use has not completed yet.
              // We need to represent a result to be able to continue the conversation.
              // As sending a new message will cancel any in-flight tool use, we represent it as failed due to cancellation.
              return .toolResultFailureMessage(.init(failure: ["error": .string("The tool use has been cancelled.")]))
            }
            let data = try JSONEncoder().encode(output)
            let jsonResult = try JSONDecoder().decode(JSON.Value.self, from: data)
            return .toolResultSuccessMessage(.init(success: jsonResult))
          } catch {
            return .toolResultFailureMessage(.init(failure: ["error": .string(error.localizedDescription)]))
          }
        }()

        let request = try Schema.MessageContent.toolUseRequest(Schema.ToolUseRequest(
          name: toolUse.toolUse.toolName,
          anyInput: toolUse.toolUse.input,
          id: toolUse.toolUse.toolUseId))
        return [
          (.assistant, request),
          (.tool, .toolResultMessage(.init(
            toolUseId: toolUse.toolUse.toolUseId,
            toolName: toolUse.toolUse.toolName,
            result: toolResult))),
        ]
      } catch {
        defaultLogger.error("Unable to serialize the tool use request.")
        return []
      }

    case .conversationSummary(let summary):
      return [(nil, .textMessage(.init(text: summary.text)))]

    case .internalContent(let content):
      return [(nil, .internalContent(content.value))]
    }
  }
}

extension AttachmentModel {

  fileprivate var apiFormat: Schema.MessageAttachment {
    switch self {
    case .file(let fileAttachment):
      return .fileAttachment(Schema.FileAttachment(
        path: fileAttachment.path.path(),
        content: fileAttachment.content))

    case .image(let imageAttachment):
      return .imageAttachment(Schema.ImageAttachment(
        url: imageData(from: imageAttachment),
        mimeType: imageAttachment.mimeType,
        path: imageAttachment.path?.path))

    case .fileSelection(let fileSelectionAttachment):
      let startLine = fileSelectionAttachment.startLine
      let endLine = fileSelectionAttachment.endLine
      let content = fileSelectionAttachment.file.content
        .split(separator: "\n", omittingEmptySubsequences: false)
        .dropFirst(startLine - 1)
        .prefix(endLine - startLine + 1)
        .joined(separator: "\n")
      return .fileSelectionAttachment(Schema.FileSelectionAttachment(
        path: fileSelectionAttachment.file.path.path(),
        content: content,
        startLine: fileSelectionAttachment.startLine,
        endLine: fileSelectionAttachment.endLine))

    case .buildError(let buildError):
      return .buildErrorAttachment(Schema.BuildErrorAttachment(
        filePath: buildError.filePath.path(),
        line: buildError.line,
        column: buildError.column,
        message: buildError.message))
    }
  }

  private func imageData(from image: AttachmentModel.ImageAttachment) -> String {
    var mimeType: String?
    if let url = image.path {
      let ext = url.pathExtension
      mimeType = ext == "png" ? "image/png" : ext == "jpg" ? "image/jpeg" : nil
    }
    let data = image.imageData
    return "data:\(mimeType ?? "image/png");base64,\(data.base64EncodedString())"
  }
}

// MARK: - API domain to state domain

extension AssistantMessageContent {
  @MainActor
  func domainFormat(projectRoot: URL?) -> ChatMessageContent {
    switch self {
    case .text(let value):
      let content = ChatMessageTextContent(projectRoot: projectRoot, deltas: value.deltas, attachments: [])
      Task {
        for await update in value.futureUpdates {
          content.catchUp(deltas: update.deltas)
        }
        content.finishStreaming()
      }
      return .text(content)

    case .tool(let value):
      let content = ChatMessageToolUseContent(toolUse: value.toolUse)
      return .toolUse(content)

    case .reasoning(let value):
      let content = ChatMessageReasoningContent(deltas: value.deltas, signature: value.signature)
      Task {
        for await update in value.futureUpdates {
          content.catchUp(deltas: update.deltas)
          content.signature = update.signature
        }
        content.finishStreaming()
      }
      return .reasoning(content)

    case .internalContent(let content):
      return .internalContent(.init(content))
    }
  }
}

extension ToolUse {

  var hasCompleted: Bool {
    if case .completed = status.value {
      return true
    }
    return false
  }

  var futureUpdates: AsyncStream<ToolUseExecutionStatus<EmptyObject>> {
    status.futureUpdates.map { event -> ToolUseExecutionStatus<EmptyObject> in
      switch event {
      case .notStarted: return .notStarted
      case .running: return .running
      case .pendingApproval: return .pendingApproval
      case .approvalRejected(reason: let reason): return .approvalRejected(reason: reason)
      case .completed(let result):
        switch result {
        case .success: return .completed(.success(EmptyObject()))
        case .failure(let error): return .completed(.failure(error))
        }
      }
    }.eraseToStream()
  }
}
