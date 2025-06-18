// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation
import Security

// MARK: - KeychainHelper

class KeychainHelper {

  @discardableResult
  static func save(key: String, value: String) -> Bool {
    let data = value.utf8Data
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecAttrService as String: service,
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]

    SecItemDelete(query as CFDictionary) // Remove any existing item
    let status = SecItemAdd(query as CFDictionary, nil)
    return status == errSecSuccess
  }

  static func load(key: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecAttrService as String: service,
      kSecReturnData as String: kCFBooleanTrue!,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    if status == errSecSuccess, let data = result as? Data {
      return String(data: data, encoding: .utf8)
    }
    return nil
  }

  @discardableResult
  static func delete(key: String) -> Bool {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecAttrService as String: service,
    ]

    let status = SecItemDelete(query as CFDictionary)
    return status == errSecSuccess
  }

  private static let service = UserDefaults.sharedSuiteName(bundle: .main) ?? "dev.getcmd.keychain"

}

extension UserDefaults {

  public func securelySave(_ value: String, forKey key: String) {
    guard isKeychainSupported else {
      return
    }
    KeychainHelper.save(key: key, value: value)
  }

  public func loadSecuredValue(forKey key: String) -> String? {
    guard isKeychainSupported else {
      return "<cannot load secured value for \(key)>"
    }
    return KeychainHelper.load(key: key)
  }

  public func removeSecuredValue(forKey key: String) {
    guard isKeychainSupported else {
      return
    }
    KeychainHelper.delete(key: key)
  }

  private var isKeychainSupported: Bool {
    // The keychain should only be used by the host app.
    // More precisely an entry written in the keychain should only be accessed by the target that wrote it,
    // otherwise trying to access it prompt the user for permission / password.
    //
    // Since the DefaultSettingService can load keys eagerly, whether from the host app or the extension,
    // we mitigate the issue by only making the keychain available to the host app which is the only context in which it is needed.
    Bundle.main.bundleIdentifier == Bundle.main.object(forInfoDictionaryKey: "APP_BUNDLE_IDENTIFIER") as? String
  }
}
