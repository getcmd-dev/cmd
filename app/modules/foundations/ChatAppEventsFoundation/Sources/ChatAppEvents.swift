// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppEventServiceInterface
import ChatFoundation
import Foundation

// MARK: - AddCodeToChatEvent

public struct AddCodeToChatEvent: AppEvent {
  public init(newThread: Bool, chatMode: ChatMode?) {
    self.newThread = newThread
    self.chatMode = chatMode
  }

  public let newThread: Bool
  public let chatMode: ChatMode?
}

// MARK: - EditCodeInlineEvent

public struct EditCodeInlineEvent: AppEvent {
  public init() { }
}

// MARK: - ChangeChatModeEvent

public struct ChangeChatModeEvent: AppEvent {
  public init(chatMode: ChatMode) {
    self.chatMode = chatMode
  }

  public let chatMode: ChatMode
}

// MARK: - NewChatEvent

public struct NewChatEvent: AppEvent {
  public init() { }
}

// MARK: - HideChatEvent

public struct HideChatEvent: AppEvent {
  public init() { }
}

// MARK: - SwitchToChatThreadEvent

public struct SwitchToChatThreadEvent: AppEvent {
  public init(threadId: UUID) {
    self.threadId = threadId
  }

  public let threadId: UUID
}
