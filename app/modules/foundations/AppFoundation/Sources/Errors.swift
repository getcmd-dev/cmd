// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - AppError

public struct AppError: LocalizedError {
  public init(message: String, debugDescription: String? = nil, underlyingError: Error? = nil) {
    self.message = message
    self.underlyingError = underlyingError
    _debugDescription = debugDescription
  }

  public init(_ error: Error) {
    self.init(message: error.localizedDescription, debugDescription: (error as CustomDebugStringConvertible).debugDescription)
  }

  public init(_ message: String) {
    self.init(message: message, debugDescription: nil)
  }

  public let message: String
  public let underlyingError: Error?
  private let _debugDescription: String?
}

extension AppError {
  public var errorDescription: String? {
    message
  }
}

// MARK: CustomNSError

extension AppError: CustomNSError {
  public var errorUserInfo: [String: Any] {
    [
      NSLocalizedDescriptionKey: message,
    ]
  }
}

// MARK: CustomDebugStringConvertible

extension AppError: CustomDebugStringConvertible {
  public var debugDescription: String {
    _debugDescription ?? ""
  }
}

extension CancellationError: @retroactive LocalizedError {
  var localizedDescription: String {
    "cancelled"
  }
}

extension AppError: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            message: try container.decode(String.self, forKey: .message),
            debugDescription: try container.decodeIfPresent(String.self, forKey: .debugDescription))
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(message, forKey: .message)
        if let debugDescription = self._debugDescription {
            try container.encode(debugDescription, forKey: .debugDescription)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case message
        case debugDescription
    }
}
