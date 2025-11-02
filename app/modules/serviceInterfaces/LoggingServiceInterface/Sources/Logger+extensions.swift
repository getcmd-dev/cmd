// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

/// Run the given task, logging any error with the given message.
@discardableResult
public func Task(
  loggingErrorWith message: String,
  logger: Logger? = nil,
  task: @escaping @Sendable () async throws -> Void)
  -> Task<Void, Never>
{
  Task {
    do {
      try await task()
    } catch {
      (logger ?? defaultLogger).error(message, error)
    }
  }
}
