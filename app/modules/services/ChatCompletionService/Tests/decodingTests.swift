import ChatCompletionService
import Testing
import Foundation
import AppFoundation

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
        #expect(input.messages.map { $0.role } == [.developer, .user])
        
    }
}
