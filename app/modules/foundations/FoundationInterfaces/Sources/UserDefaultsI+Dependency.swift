// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import DependencyFoundation
import Foundation

// MARK: - UserDefaultsProviding

public protocol UserDefaultsProviding: BaseProviding {
  var sharedUserDefaults: UserDefaultsI { get }
}

// MARK: - SharedUserDefaultsDependencyKey

public final class SharedUserDefaultsDependencyKey: TestDependencyKey {
  #if DEBUG
  public static var testValue: UserDefaultsI { MockUserDefaults() }
  #else
  /// This is not read outside of DEBUG
  public static let testValue: UserDefaultsI = () as! UserDefaults
  #endif
}

extension DependencyValues {
  public var userDefaults: UserDefaultsI {
    get { self[SharedUserDefaultsDependencyKey.self] }
    set { self[SharedUserDefaultsDependencyKey.self] = newValue }
  }
}
