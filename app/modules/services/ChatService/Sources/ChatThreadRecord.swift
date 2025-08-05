// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import GRDB

// MARK: - ChatThreadRecord

struct ChatThreadRecord: Codable, Identifiable, Sendable {
  init(
    id: String,
    name: String,
    createdAt: Date,
    rawContentPath: String)

  {
    self.id = id
    self.name = name
    self.createdAt = createdAt
    self.rawContentPath = rawContentPath
  }

  let id: String
  let name: String
  let createdAt: Date
  let rawContentPath: String

}

// MARK: FetchableRecord, PersistableRecord

extension ChatThreadRecord: FetchableRecord, PersistableRecord {
  static let databaseTableName = "chat_threads"
}
