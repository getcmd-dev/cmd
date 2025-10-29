import Foundation
import XcodeObserverServiceInterface

public struct CompletionSuggestion: Sendable {
    public let file: URL
    public let startPosition: CursorPosition
    public let completion: String
    public let id: UUID
    
    public init(file: URL, startPosition: CursorPosition, completion: String, id: UUID) {
        self.file = file
        self.startPosition = startPosition
        self.completion = completion
        self.id = id
    }
}

public protocol CodeCompletionService: Sendable {
    func provideCompletion(timeout: TimeInterval) async throws -> CompletionSuggestion
    func logCompletionAcceptance(suggestion: CompletionSuggestion, accepted: Bool)
}

