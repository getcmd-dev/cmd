// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import JSONFoundation
import ThreadSafe

#if DEBUG
/// A mock implementation of UserDefaultsI for testing purposes
@ThreadSafe
public final class MockUserDefaults: UserDefaultsI {
  public init(initialValues: [String: Any] = [:], securedStorage: [String: String] = [:]) {
    self.securedStorage = securedStorage
    storage = initialValues.mapValues { UncheckedSendable($0) }
  }

  public var onRemoveObjectForKey: (@Sendable (String) -> Void)?

  // MARK: - Core Methods

  public func object(forKey defaultName: String) -> Any? {
    storage[defaultName]?.wrapped
  }

  public func set(_ value: Any?, forKey defaultName: String) {
    set(anyValue: value, forKey: defaultName)
  }

  public func removeObject(forKey defaultName: String) {
    storage.removeValue(forKey: defaultName)
    notifyChange()
    onRemoveObjectForKey?(defaultName)
  }

  // MARK: - Type-Specific Getters

  public func string(forKey defaultName: String) -> String? {
    if let number = object(forKey: defaultName) as? NSNumber {
      return number.stringValue
    }
    return object(forKey: defaultName) as? String
  }

  public func array(forKey defaultName: String) -> [Any]? {
    object(forKey: defaultName) as? [Any]
  }

  public func dictionary(forKey defaultName: String) -> [String: Any]? {
    object(forKey: defaultName) as? [String: Any]
  }

  public func data(forKey defaultName: String) -> Data? {
    object(forKey: defaultName) as? Data
  }

  public func stringArray(forKey defaultName: String) -> [String]? {
    object(forKey: defaultName) as? [String]
  }

  public func integer(forKey defaultName: String) -> Int {
    if let number = object(forKey: defaultName) as? NSNumber {
      return number.intValue
    } else if let string = object(forKey: defaultName) as? String, let intValue = Int(string) {
      return intValue
    } else if let bool = object(forKey: defaultName) as? Bool {
      return bool ? 1 : 0
    }
    return 0
  }

  public func float(forKey defaultName: String) -> Float {
    if let number = object(forKey: defaultName) as? NSNumber {
      return number.floatValue
    } else if let string = object(forKey: defaultName) as? String, let floatValue = Float(string) {
      return floatValue
    }
    return 0.0
  }

  public func double(forKey defaultName: String) -> Double {
    if let number = object(forKey: defaultName) as? NSNumber {
      return number.doubleValue
    } else if let string = object(forKey: defaultName) as? String, let doubleValue = Double(string) {
      return doubleValue
    }
    return 0.0
  }

  public func bool(forKey defaultName: String) -> Bool {
    if let number = object(forKey: defaultName) as? NSNumber {
      return number.boolValue
    } else if let string = object(forKey: defaultName) as? String {
      return string == "YES" || string == "1"
    }
    return false
  }

  public func url(forKey defaultName: String) -> URL? {
    if let urlString = string(forKey: defaultName) {
      return URL(fileURLWithPath: urlString)
    } else if let url = object(forKey: defaultName) as? URL {
      return url
    }
    return nil
  }

  // MARK: - Type-Specific Setters

  public func set(_ value: Int, forKey defaultName: String) {
    set(anyValue: NSNumber(value: value), forKey: defaultName)
  }

  public func set(_ value: Float, forKey defaultName: String) {
    set(anyValue: NSNumber(value: value), forKey: defaultName)
  }

  public func set(_ value: Double, forKey defaultName: String) {
    set(anyValue: NSNumber(value: value), forKey: defaultName)
  }

  public func set(_ value: Bool, forKey defaultName: String) {
    set(anyValue: NSNumber(value: value), forKey: defaultName)
  }

  public func set(_ url: URL?, forKey defaultName: String) {
    set(anyValue: url, forKey: defaultName)
  }

  // MARK: - Change Notification

  public func onChange(_ callback: @MainActor @Sendable @escaping () -> Void) -> AnyCancellable {
    changeSubject
      .sink { _ in
        Task { @MainActor in
          callback()
        }
      }
  }

  // MARK: - Testing Helpers

  /// Reset all stored values
  public func reset() {
    storage.removeAll()
    notifyChange()
  }

  /// Get all stored keys
  public func allKeys() -> [String] {
    Array(storage.keys)
  }

  /// Check if a key exists
  public func hasKey(_ key: String) -> Bool {
    storage.keys.contains(key)
  }

  /// Dump all stored values (useful for debugging)
  public func dumpStorage() -> [String: Any] {
    storage.mapValues { $0.wrapped }
  }

  /// Dump all securely stored values (useful for debugging)
  public func dumpSecureStorage() -> [String: String] {
    securedStorage
  }

  public func securelySave(_ value: String, forKey key: String) {
    securedStorage[key] = value
    notifyChange()
  }

  public func loadSecuredValue(forKey key: String) -> String? {
    securedStorage[key]
  }

  public func removeSecuredValue(forKey key: String) {
    securedStorage.removeValue(forKey: key)
    notifyChange()
  }

  /// Internal storage
  private var storage = [String: UncheckedSendable<Any>]()

  private var securedStorage = [String: String]()

  /// Subject to emit change events
  private let changeSubject = PassthroughSubject<Void, Never>()

  private func set(anyValue: Any?, forKey defaultName: String) {
    if let anyValue {
      storage[defaultName] = UncheckedSendable(anyValue)
    } else {
      removeObject(forKey: defaultName)
    }
    notifyChange()
  }

  /// Helper method to notify about changes
  private func notifyChange() {
    changeSubject.send()
  }

}
#endif
