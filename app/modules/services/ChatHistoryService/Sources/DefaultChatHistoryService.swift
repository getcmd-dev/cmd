// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatFeatureInterface
import ChatHistoryServiceInterface
@preconcurrency import Combine
import CryptoKit
import DependencyFoundation
import Foundation
import FoundationInterfaces
import GRDB
import LLMServiceInterface
import LoggingServiceInterface
import ToolFoundation

let logger = defaultLogger.subLogger(subsystem: "chatHistoryService")

// MARK: - DefaultChatHistoryService

final class DefaultChatHistoryService: ChatHistoryService, Sendable {
  init(
    createDBConnection: () -> DatabaseQueue,
    fileManager: FileManagerI,
    toolsPlugin: ToolsPlugin)
  {
    self.fileManager = fileManager
    self.toolsPlugin = toolsPlugin
    dbQueue = createDBConnection()

    let (hasInitialize, fulfill) = Future<Void, Never>.make()
    self.hasInitialize = hasInitialize

    initializeTables(fulfill: fulfill)
  }

  func didInitialized() async {
    await hasInitialize.value
  }

  // MARK: - Chat Thread Operations

  func save(chatThread thread: ChatThreadModel) async throws {
    let home = fileManager.homeDirectoryForCurrentUser
    let rawContentPath = home
      .appending(
        path: ".cmd/chat-history/project-\(thread.projectInfo?.dirPath.path.sha256 ?? "sha256")-\(thread.projectInfo?.dirPath.lastPathComponent ?? "")/\(thread.createdAt.ISO8601Format())-\(thread.id.uuidString)/content.json")

    let threadRecord = ChatThreadRecord(
      id: thread.id.uuidString,
      name: thread.name,
      createdAt: thread.createdAt,
      rawContentPath: rawContentPath.path)

    // Save or update the thread metadata in the database
    try await dbQueue.write { db in
      try threadRecord.save(db)
    }

    // Write the thread content as plain JSON to the file system
    try fileManager.createDirectory(
      at: rawContentPath.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil)
    let encoder = JSONEncoder()

    let objectsDir = rawContentPath.deletingLastPathComponent().appendingPathComponent("objects")
    encoder.userInfo[AttachmentSerializer.attachmentSerializerKey] = AttachmentSerializer(
      fileManager: fileManager,
      objectsDir: objectsDir)

    let data = try encoder.encode(thread)
    try fileManager.write(data: data, to: rawContentPath, options: .atomic)
  }

  func loadLastChatThreads(last: Int, offset: Int) async throws -> [ChatThreadModelMetadata] {
    let records = try await dbQueue.read { db in
      try ChatThreadRecord
        .order(Column("createdAt").desc)
        .limit(last, offset: offset)
        .fetchAll(db)
    }
    return records.map { record in
      ChatThreadModelMetadata(
        id: UUID(uuidString: record.id) ?? UUID(),
        name: record.name,
        createdAt: record.createdAt)
    }
  }

  func loadChatThread(id: UUID) async throws -> ChatThreadModel? {
    let threadRecord = try await dbQueue.read { db in
      try ChatThreadRecord.fetchOne(db, id: id.uuidString)
    }
    guard let threadRecord else { return nil }
    let task = Task.detached(priority: .userInitiated) { () -> ChatThreadModel? in
      let rawContentPath = URL(filePath: threadRecord.rawContentPath)
      let rawContent = try self.fileManager.read(dataFrom: URL(filePath: threadRecord.rawContentPath))
      let decoder = JSONDecoder()
      decoder.userInfo.set(toolPlugin: self.toolsPlugin)

      let objectsDir = rawContentPath.deletingLastPathComponent().appendingPathComponent("objects")
      decoder.userInfo[AttachmentSerializer.attachmentSerializerKey] = AttachmentSerializer(
        fileManager: self.fileManager,
        objectsDir: objectsDir)

      do {
        return try decoder.decode(ChatThreadModel.self, from: rawContent)
      } catch {
        defaultLogger.error("Chat thread could not be loaded. Removing it.", error)
        try await self.deleteChatThread(id: id)
        return nil
      }
    }
    return try await task.value
  }

  func deleteChatThread(id: UUID) async throws {
    _ = try await dbQueue.write { db in
      try ChatThreadRecord.deleteOne(db, id: id.uuidString)
    }
  }

  // Used for testing purposes to ensure tables are created before any operations
  private let hasInitialize: Future<Void, Never>
  private let toolsPlugin: ToolsPlugin

  private let fileManager: FileManagerI

  // MARK: - Atomic Operations

  private let dbQueue: DatabaseQueue

  private func initializeTables(fulfill: @escaping @Sendable (Result<Void, Never>) -> Void) {
    Task {
      do {
        try await dbQueue.write { db in
          try self.createTables(db)
        }
        fulfill(.success(()))
        logger.log("Database tables created successfully")
      } catch {
        logger.error("Database tables could not be created. Chat history will not work", error)
      }
    }
  }

  private func createTables(_ db: Database) throws {
    // Create chat_threads table
    try db.create(table: ChatThreadRecord.databaseTableName, ifNotExists: true) { t in
      t.primaryKey("id", .text)
      t.column("name", .text).notNull()
      t.column("createdAt", .datetime).notNull()
      t.column("projectPath", .text)
      t.column("rawContentPath", .text)
    }

    // Create indexes for better performance
    try db.create(
      index: "chat_thread.created_at",
      on: ChatThreadRecord.databaseTableName,
      columns: ["createdAt"],
      ifNotExists: true)
  }

}

extension BaseProviding where
  Self: FileManagerProviding,
  Self: ToolsPluginProviding
{
  public var chatHistoryService: ChatHistoryService {
    shared {
      DefaultChatHistoryService(
        createDBConnection: {
          do {
            // Create database directory if it doesn't exist
            let documentsURLs = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            guard let documentsURL = documentsURLs.first else {
              throw NSError(
                domain: "ChatDatabaseService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not find documents directory"])
            }
            let chatDataURL = documentsURL.appendingPathComponent("\(Bundle.main.hostAppBundleId)/ChatData")

            if !fileManager.fileExists(atPath: chatDataURL.path) {
              try fileManager.createDirectory(
                at: chatDataURL,
                withIntermediateDirectories: true,
                attributes: nil)
            }

            let dbURL = chatDataURL.appendingPathComponent("chat.sqlite")
            let connection = try DatabaseQueue(path: dbURL.path)
            logger.log("Database initialized at: \(dbURL.path)")
            return connection
          } catch {
            logger.error("Failed to create database connection", error)
            return try! DatabaseQueue()
          }
        },
        fileManager: fileManager,
        toolsPlugin: toolsPlugin)
    }
  }
}

extension ChatMessageContentModel {
  var asText: ChatMessageTextContentModel? {
    guard case .text(let textContent) = self else { return nil }
    return textContent
  }

  var id: UUID {
    switch self {
    case .text(let content):
      content.id
    case .reasoning(let content):
      content.id
    case .nonUserFacingText(let content):
      content.id
    case .toolUse(let content):
      content.id
    case .conversationSummary(let content):
      content.id
    }
  }
}

extension String {
  var sha256: String {
    let data = Data(utf8)
    let hash = SHA256.hash(data: data)
    return hash.map { String(format: "%02hhx", $0) }.joined()
  }
}
