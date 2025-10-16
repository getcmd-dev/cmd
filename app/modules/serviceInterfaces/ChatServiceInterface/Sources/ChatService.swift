// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

public protocol ChatService: Sendable {
  /// Ensure the view model is strongly retained until `stopKeepingAlive` is called.
  /// Only one object is kept in memory for each thread and calling `keepAlive` twice without calling `stopKeepingAlive` in between is an error.
  /// - Parameters:
  ///   - viewModel: The view model instance to keep alive
  ///   - threadId: The unique identifier for the chat thread
  func keepAlive(_ viewModel: some AnyObject, for threadId: UUID)

  /// Release the strong reference to the view model for the given thread.
  /// After calling this method, the view model may be deallocated if no other strong references exist.
  /// - Parameters:
  ///   - viewModel: The view model instance to stop keeping alive
  ///   - threadId: The unique identifier for the chat thread
  func stopKeepingAlive(_ viewModel: some AnyObject, for threadId: UUID)

  /// Store a strong reference to the view model for the given thread in a buffer
  /// This allows to limit the reconstruction of the chat thread view model as long as the buffer is not full.
  /// This should not be relied on to keep the instance alive, as the buffered instance might be removed from the buffer at any point.
  /// - Parameters:
  ///   - viewModel: The view model instance to buffer
  ///   - threadId: The unique identifier for the chat thread
  func buffer(_ viewModel: some AnyObject, for threadId: UUID)

  /// Retrieve the view model associated with the given thread, if it is stored in the ChatService's buffer.
  /// - Parameter threadId: The unique identifier for the chat thread
  /// - Returns: The view model instance that has been kept alive by the ChatService.
  func knownObject<ViewModel: AnyObject>(for threadId: UUID) -> ViewModel?
}
