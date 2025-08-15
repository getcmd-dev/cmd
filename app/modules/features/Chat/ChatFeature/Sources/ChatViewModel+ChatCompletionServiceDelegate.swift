import ChatCompletionServiceInterface
import ConcurrencyFoundation

extension ChatViewModel: ChatCompletionServiceDelegate {
    public func handle(chatCompletion: ChatCompletionInput) async -> AsyncStream<[ChatCompletionServiceInterface.ChatEvent]> {
        if tab.id.uuidString != chatCompletion.threadId {
            // Load the correct thread.
        }
        return AsyncStream<[ChatCompletionServiceInterface.ChatEvent]> { continuation in
            Task {
                var chatEvents: [ChatCompletionServiceInterface.ChatEvent] = []
                for i in 0..<10 {
                    do {
                        try Task.checkCancellation()
                        chatEvents.append(.init(id: "\(i)", content: "\(i)\n"))
                        continuation.yield(chatEvents)
                        print("yield chat event \(i)")
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    } catch {
                        // Task cancelled
                        break
                    }
                }
                continuation.finish()
            }
        }
    }
}
