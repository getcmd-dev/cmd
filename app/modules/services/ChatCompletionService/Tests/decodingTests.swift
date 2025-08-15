// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import ChatCompletionService
import Foundation
import Testing

struct DecodingTests {
  @Test("Decoding chat completion input")
  func test_decodingChatCompletionInput() throws {
    // Given
    let json = """
      {
          "model": "test",
          "stream": true,
          "messages": [
              {
                  "role": "developer",
                  "content": "You are a helpful assistant."
              },
              {
                  "role": "user",
                  "content": "Hello!"
              }
          ]
      }
      """.utf8Data
    // Do
    let input = try JSONDecoder().decode(ChatQuery.self, from: json)
    // Validate
    #expect(input.stream == true)
    #expect(input.messages.map(\.role) == [.developer, .user])
  }
}
