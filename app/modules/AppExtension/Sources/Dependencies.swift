// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import Foundation
import FoundationInterfaces
import SettingsService
import SettingsServiceInterface

// TODO: find a way to ensure that all required dependencies are provided here.
// One possible solution could be to grab the dependencies from this module's package.swift, search their code for any `*Providing` protocol, and ensure that they are all extended here.

// MARK: - SharedUserDefaultsDependencyKey + DependencyKey

extension SharedUserDefaultsDependencyKey: DependencyKey {
  public static var liveValue: any UserDefaultsI { AppExtensionScope.shared.sharedUserDefaults }
}

// MARK: - AppExtensionScope + UserDefaultsProviding

extension AppExtensionScope: UserDefaultsProviding {
  public var sharedUserDefaults: any UserDefaultsI {
    shared {
      do {
        guard let userDefaults = try UserDefaults.shared(bundle: Bundle(for: AppExtensionScope.self)) else {
          return Foundation.UserDefaults.standard
        }
        return userDefaults
      } catch {
        return Foundation.UserDefaults.standard
      }
    }
  }
}

// MARK: - AppExtensionScope + SettingsServiceProviding

extension AppExtensionScope: SettingsServiceProviding { }

// MARK: - AppExtensionScope + FileManagerProviding

extension AppExtensionScope: FileManagerProviding {
  public var fileManager: any FileManagerI { shared { SandboxedFileManager() } }
}
