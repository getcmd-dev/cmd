// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

extension [ChatQuery.ChatCompletionMessageParam] {
  /// The thread identifier that correspond to an existing thread.
  /// To help identify existing threads, the first assistant message will contain an identifier.
  var threadId: String? {
    let regex = /^thread_id: ([a-z|A-Z|0-9|-]+)/
    return compactMap { message in
      switch message {
      case .assistant(let assistantMessage):
        switch assistantMessage.content {
        case .textContent(let text):
          return text.matches(of: regex).first?.output.1

        case .contentParts(let parts):
          for part in parts {
            switch part {
            case .text(let text):
              return text.text.matches(of: regex).first?.output.1
            }
          }

        case .none:
          break
        }

      default:
        break
      }
      return nil
    }.first?.map { String($0) }
  }

  /// The messages from user that were sent after the last response from the assistant.
  var newUserMessages: [ChatQuery.ChatCompletionMessageParam.UserMessageParam] {
    var newUserMessages = [ChatQuery.ChatCompletionMessageParam.UserMessageParam]()
    for message in self {
      switch message {
      case .user(let userMessage):
        newUserMessages.append(userMessage)
      default:
        newUserMessages = []
      }
    }
    return newUserMessages
  }
}

extension ChatQuery.ChatCompletionMessageParam.UserMessageParam {
  /// All the text elements contained in the user message.
  var textContentParts: [String] {
    var result: [String] = []
    switch content {
    case .string(let text):
      result.append(text)
    case .contentParts(let parts):
      for part in parts {
        switch part {
        case .text(let text):
          result.append(text.text)
        case .audio, .file, .image:
          break
        }
      }
    }
    return result
  }
}
