// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ChatThreadViewModel

public struct ChatThreadModel: Sendable {
  public init(
    id: UUID,
    name: String,
    messages: [ChatMessageModel],
    events: [ChatEventModel],
    projectInfo: SelectedProjectInfo?,
    knownFilesContent: [String: String],
    createdAt: Date)
  {
    self.id = id
    self.name = name
    self.messages = messages
    self.events = events
    self.projectInfo = projectInfo
    self.knownFilesContent = knownFilesContent
    self.createdAt = createdAt
  }

  /// Information about the Xcode project/workspace/swift package that this thread is about.
  public struct SelectedProjectInfo: Sendable {
    /// The path to the project
    public let path: URL
    /// The dir containing the project (same as the path for a Swift Package)
    public let dirPath: URL

    public init(path: URL, dirPath: URL) {
      self.path = path
      self.dirPath = dirPath
    }
  }

  public let id: UUID
  public let name: String
  public let messages: [ChatMessageModel]
  public let events: [ChatEventModel]
  public let projectInfo: SelectedProjectInfo?
  public let knownFilesContent: [String: String]
  public let createdAt: Date

}
