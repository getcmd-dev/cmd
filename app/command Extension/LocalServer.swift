// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppExtension
import Foundation
import FoundationInterfaces
import LoggingServiceInterface
import SharedUtilsFoundation
import SharedValuesFoundation

// MARK: - ExecuteCommandWrapper

/// Envelope structure expected by the local server's /execute-command endpoint
private struct ExecuteCommandWrapper<Input: Encodable>: Encodable {
  let type: String
  let command: String
  let input: Input
}

// MARK: - LocalServer

/// A class that communicates with the local server running in the host app.
///
/// As the extension is loaded by Xcode when it launches and will be disable if its code changes while Xcode is running,
/// it is hard to work with the extension when iterating on its code - usually in Debug mode.
/// To mitigate this issue, there is an internal setting that makes the Debug app communicate with the Release app's extension.
/// This is allows to iterate on the Debug app and still have a stable extension to communicate to and is a good workflow unless you are actively developping the extension itself.
final class LocalServer {

  /// Sends a request to the local server and returns the response.
  /// - Parameters:
  ///   - request: The typed extension request to send to the local server.
  /// - Returns: The decoded response from the local server.
  func send<Response: Decodable>(_ request: ExtensionRequest) async throws -> Response {
    try await sendRaw(request, retryCount: 0)
  }

  /// Sends a user-defined shortcut request to the local server.
  /// - Parameters:
  ///   - command: The command name for the user-defined shortcut
  ///   - input: The input data for the shortcut
  /// - Returns: The decoded response from the local server.
  func sendUserDefinedShortcut<Response: Decodable>(
    command: String,
    input: some Codable)
    async throws -> Response
  {
    let request = UserDefinedShortcutRequest(command: command, input: input)
    return try await sendRaw(request, retryCount: 0)
  }

  /// Sends a request to the local server and returns the response.
  /// - Parameters:
  ///   - request: The request to send to the local server (must be Encodable).
  ///   - retryCount: The number of times we already sent the request.
  ///   - ignoreDebugAppCheck: For Release, whether to communicate with the Release host's app's local server regardless of the setting.
  /// - Returns: The decoded response from the local server.
  private func sendRaw<Response: Decodable>(
    _ request: some Encodable,
    retryCount: Int,
    ignoreDebugAppCheck: Bool = false)
    async throws -> Response
  {
    let isReleaseExtensionCommunicatingWithDebugAppFromRelease = {
      #if DEBUG
      return false
      #else
      return AppExtensionScope.shared.sharedUserDefaults
        .bool(forKey: SharedKeys.pointReleaseXcodeExtensionToDebugApp) && !ignoreDebugAppCheck
      #endif
    }()
    let userDefaults = isReleaseExtensionCommunicatingWithDebugAppFromRelease
      ? try UserDefaults.debugShared(bundle: Bundle.main)
      : try UserDefaults.shared(bundle: Bundle.main)

    guard let port = userDefaults?.integer(forKey: UserDefaultKeys.localServerPort) else {
      defaultLogger.error("Could not find a port to connect to the local server.")
      throw XcodeExtensionError(message: "Failed to run.")
    }

    // Send request to host app.
    guard let url = URL(string: "http://localhost:\(port)/execute-command") else {
      defaultLogger.error("Could not create a URL for the local server at port \(port)")
      throw XcodeExtensionError(message: "Failed to run.")
    }
    defaultLogger.log("Sending extension request to local server.")

    do {
      let bodyData = try JSONEncoder().encode(request)
      var urlRequest = URLRequest(url: url)
      urlRequest.httpMethod = "POST"
      urlRequest.httpBody = bodyData
      urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
      let (data, _) = try await URLSession.shared.data(for: urlRequest)
      return try JSONDecoder().decode(Response.self, from: data)
    } catch {
      if
        (error as? URLError)?.code == .cannotConnectToHost,
        retryCount == 0
      {
        // We could not connect to the local server.
        if isReleaseExtensionCommunicatingWithDebugAppFromRelease {
          // Most likely the Debug app is not running and we can't reach its server. We don't try to open it and instead retry with the Release app.
          return try await sendRaw(request, retryCount: retryCount, ignoreDebugAppCheck: true)
        } else {
          // If we could not connect to the host app, try to open it and retry once.
          try OpenHostApp.openHostApp { XcodeExtensionError(message: $0) }
          return try await sendRaw(request, retryCount: retryCount + 1)
        }
      }
      defaultLogger.error("Failed to send request to the local server: \(error)")
      throw XcodeExtensionError(message: "Failed to run.")
    }
  }

}
