// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import Foundation
import LLMServiceInterface
import LocalServerServiceInterface
import Testing
@testable import LLMService

@Suite("Helpers Reasoning Tests")
struct HelpersReasoningTests {

  @Test("AssistantMessageContent asReasoning returns reasoning stream when content is reasoning")
  func testAsReasoningReturnsReasoningStream() {
    let reasoningMessage = ReasoningContentMessage(
      content: "Thinking about this problem...",
      deltas: ["Thinking", " about", " this", " problem..."],
      signature: "sig123")
    let reasoningStream = MutableCurrentValueStream(reasoningMessage)
    let content = AssistantMessageContent.reasoning(reasoningStream)

    let result = content.asReasoning
    #expect(result != nil)
    #expect(result?.value.content == "Thinking about this problem...")
    #expect(result?.value.signature == "sig123")
  }

  @Test("AssistantMessageContent asReasoning returns nil when content is text")
  func testAsReasoningReturnsNilForTextContent() {
    let textMessage = TextContentMessage(content: "Hello world", deltas: ["Hello", " world"])
    let textStream = MutableCurrentValueStream(textMessage)
    let content = AssistantMessageContent.text(textStream)

    let result = content.asReasoning
    #expect(result == nil)
  }
}
