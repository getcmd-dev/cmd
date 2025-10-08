// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

public enum XPCError: Error, LocalizedError {
  case notConnected
  case invalidProxy
  case versionMismatch

  public var errorDescription: String? {
    switch self {
    case .notConnected:
      "Not connected to XPC service"
    case .invalidProxy:
      "Invalid XPC proxy"
    case .versionMismatch:
      "XPC service version mismatch"
    }
  }
}
