// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import DependencyFoundation
import Foundation

// MARK: - FileManagerProviding

public protocol FileManagerProviding {
  var fileManager: FileManagerI { get }
}

extension BaseProviding {
  public var fileManager: FileManagerI {
    FileManager.default
  }
}

// MARK: - FileManagerDependencyKey

public final class FileManagerDependencyKey: TestDependencyKey {
  #if DEBUG
  public static var testValue: FileManagerI { MockFileManager() }
  #else
  /// This is not read outside of DEBUG
  public static let testValue: FileManagerI = () as! FileManagerI
  #endif
}

extension DependencyValues {
  public var fileManager: FileManagerI {
    get { self[FileManagerDependencyKey.self] }
    set { self[FileManagerDependencyKey.self] = newValue }
  }
}
