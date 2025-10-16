// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import ThreadSafe

#if DEBUG
@ThreadSafe
public final class MockChatService: ChatService {

  public init() { }

  public var onKeepAlive: (@Sendable (Any, UUID) -> Void)?
  public var onStopKeepingAlive: (@Sendable (Any, UUID) -> Void)?
  public var onBuffer: (@Sendable (Any, UUID) -> Void)?
  public var onKnownObject: (@Sendable (UUID) -> Any?)?

  public func keepAlive(_ viewModel: some AnyObject, for threadId: UUID) {
    if let onKeepAlive {
      onKeepAlive(viewModel, threadId)
    } else {
      storage[threadId] = SendableBox(viewModel)
    }
  }

  public func clearBuffer() {
    bufferedStorage.removeAll()
  }

  public func stopKeepingAlive(_ viewModel: some AnyObject, for threadId: UUID) {
    if let onStopKeepingAlive {
      onStopKeepingAlive(viewModel, threadId)
    } else {
      storage.removeValue(forKey: threadId)
    }
  }

  public func buffer(_ viewModel: some AnyObject, for threadId: UUID) {
    if let onBuffer {
      onBuffer(viewModel, threadId)
    } else {
      bufferedStorage[threadId] = SendableWeakBox(viewModel)
    }
  }

  public func knownObject<ViewModel: AnyObject>(for threadId: UUID) -> ViewModel? {
    if let onKnownObject {
      return onKnownObject(threadId) as? ViewModel
    } else {
      if let strongRef = storage[threadId]?.value as? ViewModel {
        return strongRef
      }
      return bufferedStorage[threadId]?.value as? ViewModel
    }
  }

  private final class SendableBox: @unchecked Sendable {
    init(_ value: AnyObject) {
      self.value = value
    }

    let value: AnyObject
  }

  private final class SendableWeakBox: @unchecked Sendable {
    init(_ value: AnyObject) {
      self.value = value
    }

    weak var value: AnyObject?
  }

  private var storage = [UUID: SendableBox]()
  private var bufferedStorage = [UUID: SendableWeakBox]()

}
#endif
