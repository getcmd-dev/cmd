// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import Foundation
import FoundationInterfaces
import LoggingServiceInterface

// TODO: find a way to ensure that all required dependencies are provided here.
// One possible solution could be to grab the dependencies from this module's package.swift, search their code for any `*Providing` protocol, and ensure that they are all extended here.

// MARK: - SharedUserDefaultsDependencyKey + DependencyKey

extension SharedUserDefaultsDependencyKey: DependencyKey {
  public static var liveValue: any UserDefaultsI { AppLauncherScope.shared.sharedUserDefaults }
}

// MARK: - AppLauncherScope + UserDefaultsProviding

extension AppLauncherScope: UserDefaultsProviding {
  public var sharedUserDefaults: any UserDefaultsI {
    shared {
      do {
        guard let userDefaults = try UserDefaults.shared(bundle: Bundle(for: AppLauncherScope.self)) else {
          defaultLogger
            .error(
              "Failed to load shared UserDefaults, falling back to standard UserDefaults. This may cause issues with data consistency.")
          return Foundation.UserDefaults.standard
        }
        return userDefaults
      } catch {
        defaultLogger.error(
          "Failed to load shared UserDefaults, falling back to standard UserDefaults. This may cause issues with data consistency.",
          error)
        return Foundation.UserDefaults.standard
      }
    }
  }

}

// MARK: - AppLauncherScope + FileManagerProviding

extension AppLauncherScope: FileManagerProviding { }
