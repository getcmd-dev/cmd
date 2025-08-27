// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import DependencyFoundation
import Foundation
import FoundationInterfaces
import JSONFoundation
import LLMFoundation
import LoggingServiceInterface
import SettingsServiceInterface
import SharedValuesFoundation
import ThreadSafe

// MARK: - DefaultSettingsService

@ThreadSafe
final class DefaultSettingsService: SettingsService {

  // MARK: - Initialization

  init(sharedUserDefaults: UserDefaultsI, releaseSharedUserDefaults: UserDefaultsI?) {
    self.sharedUserDefaults = sharedUserDefaults
    self.releaseSharedUserDefaults = releaseSharedUserDefaults
    settings = CurrentValueSubject<Settings, Never>(Self.loadSettings(from: sharedUserDefaults))

    observeChangesToUserDefaults()
  }

  // MARK: - Constants

  enum Keys {
    static let appWideSettings = "appWideSettings"
  }

  // MARK: - SettingsService Implementation

  func value<T: Equatable>(for keypath: KeyPath<Settings, T>) -> T {
    settings.value[keyPath: keypath]
  }

  func liveValue<T: Equatable>(for keypath: KeyPath<Settings, T>) -> ReadonlyCurrentValueSubject<T, Never> {
    ReadonlyCurrentValueSubject(
      settings.value[keyPath: keypath],
      publisher: settings.map { $0[keyPath: keypath] }.removeDuplicates().eraseToAnyPublisher())
  }

  func values() -> Settings {
    settings.value
  }

  func liveValues() -> ReadonlyCurrentValueSubject<Settings, Never> {
    settings.readonly(removingDuplicate: true)
  }

  func update<T>(setting: WritableKeyPath<Settings, T>, to value: T) {
    var newSettings = settings.value
    newSettings[keyPath: setting] = value
    update(to: newSettings)
  }

  func update(to newSettings: Settings) {
    settings.send(newSettings)
    persist(settings: newSettings)
  }

  func resetToDefault<T>(setting: WritableKeyPath<Settings, T>) {
    update(setting: setting, to: Self.defaultSettings[keyPath: setting])
  }

  func resetAllToDefault() {
    settings.send(Self.defaultSettings)
    Task { @MainActor in
      persist(settings: Self.defaultSettings)
    }
  }

  /// Decode the value here to ensure that we are using the default values used in decoding.
  private static let defaultSettings = try! JSONDecoder().decode(Settings.self, from: "{}".utf8Data)

  private let settings: CurrentValueSubject<Settings, Never>
  private var notificationObserver: AnyCancellable?

  private let sharedUserDefaults: UserDefaultsI
  private let releaseSharedUserDefaults: UserDefaultsI?

  private static func loadSettings(from userDefaults: UserDefaultsI) -> Settings {
    if let data = userDefaults.data(forKey: Keys.appWideSettings) {
      do {
        var settings = try JSONDecoder().decode(Settings.self, from: data)
        // Load API keys fromn the keychain.
        if let anthropicAPIKey = settings.llmProviderSettings[.anthropic]?.apiKey {
          if let key = userDefaults.loadSecuredValue(forKey: anthropicAPIKey) {
            settings.llmProviderSettings[.anthropic]?.apiKey = key
          } else {
            settings.llmProviderSettings.removeValue(forKey: .anthropic)
          }
        }
        if let openAIAPIKey = settings.llmProviderSettings[.openAI]?.apiKey {
          if let key = userDefaults.loadSecuredValue(forKey: openAIAPIKey) {
            settings.llmProviderSettings[.openAI]?.apiKey = key
          } else {
            settings.llmProviderSettings.removeValue(forKey: .openAI)
          }
        }
        if let openRouterAPIKey = settings.llmProviderSettings[.openRouter]?.apiKey {
          if let key = userDefaults.loadSecuredValue(forKey: openRouterAPIKey) {
            settings.llmProviderSettings[.openRouter]?.apiKey = key
          } else {
            settings.llmProviderSettings.removeValue(forKey: .openRouter)
          }
        }

        // Load pointReleaseXcodeExtensionToDebugApp that is stored separately
        settings.pointReleaseXcodeExtensionToDebugApp = userDefaults.bool(forKey: SharedKeys.pointReleaseXcodeExtensionToDebugApp)

        return settings
      } catch {
        defaultLogger.error(error)
      }
    }
    return Self.defaultSettings
  }

  /// This can be mobed back to init once https://github.com/swiftlang/swift/issues/80050 is fixed.
  private func observeChangesToUserDefaults() {
    notificationObserver = sharedUserDefaults.onChange { [weak self] in
      guard let self else { return }

      let newSettings = Self.loadSettings(from: sharedUserDefaults)
      settings.send(newSettings)
    }
  }

  private func persist(settings: Settings) {
    Task { @MainActor in
      do {
        // Persist settings to user defaults, but move keys to the keychain.
        var publicSettings = settings

        var privateKeys = [String: String?]()

        for provider in LLMProvider.allCases {
          if let settings = settings.llmProviderSettings[provider] {
            privateKeys[provider.keychainKey] = settings.apiKey
            publicSettings.llmProviderSettings[provider]?.apiKey = provider.keychainKey
          } else {
            privateKeys[provider.keychainKey] = nil
          }
        }
        let value = try JSONEncoder.sortingKeys.encode(publicSettings)
        sharedUserDefaults.set(value, forKey: Keys.appWideSettings)

        for (key, value) in privateKeys {
          if let value {
            sharedUserDefaults.securelySave(value, forKey: key)
          } else {
            sharedUserDefaults.removeSecuredValue(forKey: key)
          }
        }

        // Store this value separately in the keychain, as it can also be accessed by the release version.
        sharedUserDefaults.set(
          settings.pointReleaseXcodeExtensionToDebugApp,
          forKey: SharedKeys.pointReleaseXcodeExtensionToDebugApp)
      } catch {
        defaultLogger.error(error)
      }
      #if DEBUG
      /// Write pointReleaseXcodeExtensionToDebugApp to the release settings.

      let releaseUserDefaults = releaseSharedUserDefaults
      releaseUserDefaults?.set(
        settings.pointReleaseXcodeExtensionToDebugApp,
        forKey: SharedKeys.pointReleaseXcodeExtensionToDebugApp)
      #endif
    }
  }

}

// MARK: - Dependency Registration

extension BaseProviding where Self: UserDefaultsProviding {
  public var settingsService: SettingsService {
    shared {
      let releaseSharedUserDefaults: UserDefaultsI? = {
        #if DEBUG
        do {
          return try UserDefaults.releaseShared(bundle: .main)
        } catch {
          defaultLogger.error(error)
          return nil
        }
        #else
        return nil
        #endif
      }()

      return DefaultSettingsService(sharedUserDefaults: sharedUserDefaults, releaseSharedUserDefaults: releaseSharedUserDefaults)
    }
  }
}

// MARK: - WritableKeyPath + Sendable

extension WritableKeyPath: Sendable where Root: Sendable, Value: Sendable { }
