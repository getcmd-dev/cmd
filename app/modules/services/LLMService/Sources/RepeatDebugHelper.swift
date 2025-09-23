// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Combine
import Foundation
import FoundationInterfaces
import SettingsServiceInterface
import ThreadSafe

#if DEBUG
/// This debugging helper allows to repeat the last saved interaction with an LLM.
/// Toggle Repeat last chat session in the settings to enable/disable this feature.
///
/// This can be helpful when iterating on an issue to avoid waiting on the LLM and dealing with not receiving the same responses.
///
/// Not the best code, but it does the job. DEBUG only.
@ThreadSafe
final class RepeatDebugHelper: Sendable {
  init(userDefaults: UserDefaultsI) {
    self.userDefaults = userDefaults
    isRepeating = userDefaults.bool(forKey: .repeatLastLLMInteraction)
    startSession()
  }

  let userDefaults: UserDefaultsI
  let isRepeating: Bool

  var streams: [Stream] = []
  var streamStartedAt: Date?

  func startSession() {
    if !isRepeating { return }
    guard
      let streamsData = userDefaults.data(forKey: "llmService.savedStreams"),
      let streams = try? JSONDecoder().decode([Stream].self, from: streamsData)
    else { return }
    self.streams = streams
  }

  func receive(chunk: Data) {
    if isRepeating { return }
    let streams = inLock { state in
      let chunk = String(data: chunk, encoding: .utf8)!
      if let streamStartedAt = state.streamStartedAt, var stream = state.streams.last {
        stream.chunks.append(.init(chunk: chunk, receivedAfter: Date().timeIntervalSince(streamStartedAt)))
        state.streams[state.streams.count - 1] = stream
      } else {
        state.streamStartedAt = Date()
        state.streams.append(Stream(chunks: [.init(chunk: chunk, receivedAfter: 0)]))
      }
      return state.streams
    }
    userDefaults.set(try? JSONEncoder().encode(streams), forKey: "llmService.savedStreams")
  }

  func streamCompleted() {
    if isRepeating { return }
    inLock { state in
      state.streamStartedAt = nil
    }
  }

  func repeatStream() throws -> AsyncThrowingStream<Data, any Error>? {
    guard isRepeating else { return nil }
    let stream: Stream? = inLock { state in
      if state.streams.isEmpty {
        return nil
      }
      return state.streams.removeFirst()
    }
    guard let stream else {
      throw AppError("no more saved stream to repeat")
    }
    return AsyncThrowingStream { continuation in
      Task {
        for chunk in stream.chunks {
          continuation.yield(chunk.chunk.utf8Data)
        }
        continuation.finish()
      }
    }
  }

}

struct Stream: Codable {
  var chunks: [Chunk]

  struct Chunk: Codable {
    var chunk: String
    var receivedAfter: TimeInterval
  }
}
#endif
