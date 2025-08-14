// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ChatCompletionServiceInterface
import DependencyFoundation
import SettingsServiceInterface
import ThreadSafe

// MARK: - DefaultChatCompletionService

//@ThreadSafe
final class DefaultChatCompletionService: ChatCompletionService {
  
  // MARK: - Initialization
  
    init(settingsService: SettingsService) {
        self.settingsService = settingsService
  }
  
  // MARK: - ChatCompletionService Implementation
  
  func respond(to request: ChatCompletionRequest) throws -> AsyncStream<CompletionResponseChunk> {
      AsyncStream { continuation in
          continuation.finish()
      }
//    try localServer.respond(to: request)
  }
  
  func respond(to request: ListModelsRequest) async throws -> ListModelsResponse {
      ListModelsResponse(models: settingsService.liveValues().currentValue.availableModels.map { model in
          ListModelsResponse.Models(id: model.id, name: model.name)
      })
  }
    let settingsService: SettingsService
}

// MARK: - Dependency Registration

extension BaseProviding where Self: SettingsServiceProviding {
  public var chatCompletionService: ChatCompletionService {
    shared {
        DefaultChatCompletionService(settingsService: settingsService)
    }
  }
}
