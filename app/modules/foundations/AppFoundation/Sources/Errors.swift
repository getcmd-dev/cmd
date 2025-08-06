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
