// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import LocalServerServiceInterface

public typealias ChatCompletionRequest = Schema.ChatCompletionRequest
public typealias CompletionResponseChunk = Schema.CompletionResponseChunk
public typealias ListModelsRequest = Schema.ListModelsRequest
public typealias ListModelsResponse = Schema.ListModelsResponse

// MARK: - ChatCompletionService

public protocol ChatCompletionService: Sendable {
    func respond(to request: ChatCompletionRequest) throws -> AsyncStream<CompletionResponseChunk>
    func respond(to request: ListModelsRequest) async throws -> ListModelsResponse
}
