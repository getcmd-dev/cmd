// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import JSONFoundation
import LoggingServiceInterface
import ThreadSafe
import ToolFoundation

// MARK: - ChatThreadContext

@ThreadSafe
final class ChatThreadContext: LiveToolExecutionContext {

  init(
    knownFilesContent: [String: String] = [:],
    userInfo: [String: any Codable & Sendable] = [:],
    requestPersistence: @escaping @Sendable () -> Void = { })
  {
    self.knownFilesContent = knownFilesContent
    self.userInfo = userInfo
    _requestPersistence = requestPersistence
  }

  private(set) var knownFilesContent: [String: String]
  private(set) var userInfo: [String: any Codable & Sendable]

  func handle(requestPersistence: @escaping @Sendable () -> Void) {
    _requestPersistence = requestPersistence
  }

  func knownFileContent(for path: URL) -> String? {
    knownFilesContent[path.absoluteString]
  }

  func set(knownFileContent: String, for path: URL) {
    knownFilesContent[path.absoluteString] = knownFileContent
  }

  func pluginState<T>(for key: String) -> T? where T: Decodable, T: Encodable, T: Sendable {
    if let decodedObject = userInfo[key] as? T {
      return decodedObject
    }
    if let object = userInfo[key] as? JSON {
      do {
        let decodedObject = try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object, options: []))
        userInfo[key] = decodedObject
        return decodedObject
      } catch {
        defaultLogger.error(error)
      }
    }
    return nil
  }

  func set(pluginState value: some Decodable & Encodable & Sendable, for key: String) {
    userInfo[key] = value
  }

  func requestPersistence() {
    _requestPersistence()
  }

  private var _requestPersistence: @Sendable () -> Void

}
