// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppEventServiceInterface
import Foundation
// MARK: - ExecuteExtensionRequestEvent

// TODO: make more generic than for extension
public struct ExecuteExtensionRequestEvent: AppEvent {

  public init(
    command: String,
    id: String,
    data: Data,
    completion: @escaping @Sendable (Result<any Encodable & Sendable, Error>) -> Void)
  {
    self.command = command
    self.id = id
    self.data = data
    self.completion = completion
  }

  public let command: String
  public let id: String
  public let data: Data
  public let completion: @Sendable (Result<any Encodable & Sendable, Error>) -> Void
}
