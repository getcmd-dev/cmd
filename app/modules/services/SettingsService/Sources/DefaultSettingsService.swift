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
import System
import ThreadSafe

// MARK: - DefaultSettingsService

@ThreadSafe
final class DefaultSettingsService: SettingsService {

  // MARK: - Initialization

  convenience init(
    fileManager: FileManagerI,
    sharedUserDefaults: UserDefaultsI,
    releaseSharedUserDefaults: UserDefaultsI?)
  {
    self.init(
      fileManager: fileManager,
      settingsFileLocation: fileManager.homeDirectoryForCurrentUser.appending(path: ".cmd/settings.json"),
      sharedUserDefaults: sharedUserDefaults,
      releaseSharedUserDefaults: releaseSharedUserDefaults)
  }

  package init(
    fileManager: FileManagerI,
    settingsFileLocation: URL,
    sharedUserDefaults: UserDefaultsI,
    releaseSharedUserDefaults: UserDefaultsI?)
  {
    self.fileManager = fileManager
    self.settingsFileLocation = settingsFileLocation
    self.sharedUserDefaults = sharedUserDefaults
    self.releaseSharedUserDefaults = releaseSharedUserDefaults
    settings = CurrentValueSubject<Settings, Never>(defaultSettings)
    settings.send(loadSettings())

    observeChangesToUserDefaults()
  }

  // MARK: - Constants

  enum Keys {
    static let appWideSettings = "appWideSettings"
    static let internalSettings = "internalSettings"
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
    Task { @MainActor in
      do {
        try persist(settings: newSettings)
      } catch {
        defaultLogger.error("Failed to persist settings", error)
      }
    }
  }

  func resetToDefault<T>(setting: WritableKeyPath<Settings, T>) {
    update(setting: setting, to: defaultSettings[keyPath: setting])
  }

  func resetAllToDefault() {
    update(to: defaultSettings)
  }

  /// Decode the value here to ensure that we are using the default values used in decoding.
  private let defaultSettings = Settings(externalSettings: .defaultSettings, internalSettings: .defaultSettings)

  private let settings: CurrentValueSubject<Settings, Never>
  private var notificationObserver: AnyCancellable?

  private let fileManager: FileManagerI
  private let settingsFileLocation: URL
  private let sharedUserDefaults: UserDefaultsI
  private let releaseSharedUserDefaults: UserDefaultsI?

  private func loadSettings() -> Settings {
    if
      let settings = loadAndMigrateLegacySettings()
    {
      return settings
    }

    var internalSettings: InternalSettings = sharedUserDefaults.data(forKey: Keys.internalSettings).map { data in
      do {
        return try JSONDecoder().decode(InternalSettings.self, from: data)
      } catch {
        defaultLogger.error("Failed to decode internal settings", error)
        return nil
      }
    } ??? .defaultSettings

    // Load pointReleaseXcodeExtensionToDebugApp that is stored separately
    internalSettings.pointReleaseXcodeExtensionToDebugApp = sharedUserDefaults
      .bool(forKey: SharedKeys.pointReleaseXcodeExtensionToDebugApp)

    var externalSettings: ExternalSettings = (try? fileManager.read(dataFrom: settingsFileLocation))
      .map { data in
        do {
          return try JSONDecoder().decode(ExternalSettings.self, from: data)
        } catch {
          defaultLogger.error("Failed to decode external settings", error)
          return nil
        }
      } ??? .defaultSettings

    // Load API keys from the keychain.
    for provider in LLMProvider.allCases {
      if let apiKey = externalSettings.llmProviderSettings[provider]?.apiKey {
        if let key = sharedUserDefaults.loadSecuredValue(forKey: apiKey) {
          externalSettings.llmProviderSettings[provider]?.apiKey = key
        } else {
          externalSettings.llmProviderSettings.removeValue(forKey: provider)
        }
      }
    }

    return Settings(externalSettings: externalSettings, internalSettings: internalSettings)
  }

  private func loadAndMigrateLegacySettings() -> Settings? {
    if let data = sharedUserDefaults.data(forKey: Keys.appWideSettings) {
      do {
        let settings: Settings = try {
          var settings = try JSONDecoder().decode(Settings.self, from: data)
          // Load API keys from the keychain.
          for provider in LLMProvider.allCases {
            if let apiKey = settings.llmProviderSettings[provider]?.apiKey {
              if let key = sharedUserDefaults.loadSecuredValue(forKey: apiKey) {
                settings.llmProviderSettings[provider]?.apiKey = key
              } else {
                settings.llmProviderSettings.removeValue(forKey: provider)
              }
            }
          }

          // Load pointReleaseXcodeExtensionToDebugApp that is stored separately
          settings.pointReleaseXcodeExtensionToDebugApp = sharedUserDefaults
            .bool(forKey: SharedKeys.pointReleaseXcodeExtensionToDebugApp)
          return settings
        }()

        // Migrate to new storage locations.
        Task { @MainActor in
          do {
            // Deactivate notifications from user defaults while migrating.
            notificationObserver = nil
            try persist(settings: settings)
            self.observeChangesToUserDefaults()
            sharedUserDefaults.removeObject(forKey: Keys.appWideSettings)
          } catch {
            defaultLogger.error("Failed to migrate settings to new location", error)
            self.observeChangesToUserDefaults()
          }
        }
        return settings
      } catch {
        defaultLogger.error(error)
      }
    }
    return nil
  }

  @MainActor
  private func persist(settings: Settings) throws {
    // Persist settings, but move keys to the keychain.
    var publicSettings = settings

    var privateKeys = [String: String?]()

    let keychainKeyPrefix = "cmd-keychain-key-"
    for provider in LLMProvider.allCases {
      let keychainKey = keychainKeyPrefix + provider.keychainKey
      if let settings = settings.llmProviderSettings[provider] {
        privateKeys[keychainKey] = settings.apiKey
        publicSettings.llmProviderSettings[provider]?.apiKey = keychainKey
      } else {
        privateKeys[keychainKey] = nil
      }
    }

    // keys are written to the keychain.
    for (key, value) in privateKeys {
      if let value {
        sharedUserDefaults.securelySave(value, forKey: key)
      } else {
        sharedUserDefaults.removeSecuredValue(forKey: key)
      }
    }

    // Internal settings are written to user defaults.
    let internalSettings = try JSONEncoder.sortingKeys.encode(publicSettings.internalSettings)
    sharedUserDefaults.set(internalSettings, forKey: Keys.internalSettings)

    // External settings are written to json files at known locations, that can easily be edited by users.
    try publicSettings.externalSettings.writeNonDefaultValues(to: settingsFileLocation, fileManager: fileManager)

    // Store this value separately in user defaults, as it can also be accessed by the release version.
    sharedUserDefaults.set(
      settings.pointReleaseXcodeExtensionToDebugApp,
      forKey: SharedKeys.pointReleaseXcodeExtensionToDebugApp)
    #if DEBUG
    /// Write pointReleaseXcodeExtensionToDebugApp to the release settings.

    let releaseUserDefaults = releaseSharedUserDefaults
    releaseUserDefaults?.set(
      settings.pointReleaseXcodeExtensionToDebugApp,
      forKey: SharedKeys.pointReleaseXcodeExtensionToDebugApp)
    #endif
  }

  /// This can be moved back to init once https://github.com/swiftlang/swift/issues/80050 is fixed.
  private func observeChangesToUserDefaults() {
    notificationObserver = sharedUserDefaults.onChange { [weak self] in
      guard let self else { return }

      let newSettings = loadSettings()
      settings.send(newSettings)
    }
  }

}

// MARK: - Dependency Registration

extension BaseProviding where Self: UserDefaultsProviding, Self: FileManagerProviding {
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

      return DefaultSettingsService(
        fileManager: fileManager,
        sharedUserDefaults: sharedUserDefaults,
        releaseSharedUserDefaults: releaseSharedUserDefaults)
    }
  }
}

// MARK: - WritableKeyPath + Sendable

extension WritableKeyPath: Sendable where Root: Sendable, Value: Sendable { }
