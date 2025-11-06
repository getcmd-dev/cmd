// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - QueuedMessageModel

/// Represents a message that has been queued for sending while the assistant is streaming a response.
public struct QueuedMessageModel: Identifiable, Sendable {
  public init(
    id: UUID,
    text: String,
    attachments: [AttachmentModel],
    createdAt: Date)
  {
    self.id = id
    self.text = text
    self.attachments = attachments
    self.createdAt = createdAt
  }

  public let id: UUID
  /// The text content of the queued message
  public let text: String
  /// Attachments associated with this queued message
  public let attachments: [AttachmentModel]
  /// When this message was queued
  public let createdAt: Date
}
