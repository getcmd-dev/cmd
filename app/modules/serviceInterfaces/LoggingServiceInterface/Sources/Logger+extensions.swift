// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

/// Run the given task, logging any error with the given message.
@discardableResult
public func Task<Result>(
  loggingErrorWith message: String,
  logger: Logger? = nil,
  task: @escaping @Sendable () async throws -> Result)
  -> Task<Result, Error>
{
  Task {
    do {
      return try await task()
    } catch {
      (logger ?? defaultLogger).error(message, error)
      throw error
    }
  }
}

public func run<Result>(
  loggingErrorWith message: String,
  logger: Logger? = nil,
  task: () throws -> Result)
  throws -> Result
{
  do {
    return try task()
  } catch {
    (logger ?? defaultLogger).error(message, error)
    throw error
  }
}

public func run<Result>(
  loggingErrorWith message: String,
  logger: Logger? = nil,
  task: () async throws -> Result)
  async throws -> Result
{
  do {
    return try await task()
  } catch {
    (logger ?? defaultLogger).error(message, error)
    throw error
  }
}
