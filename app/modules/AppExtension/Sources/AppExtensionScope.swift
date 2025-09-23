// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import DependencyFoundation
import Foundation
import LoggingService
import LoggingServiceInterface
import ThreadSafe

// MARK: - AppExtensionScope

@ThreadSafe
public final class AppExtensionScope: Sendable, BaseProviding {

  init() {
    setupLogging()
  }

  public static let shared = AppExtensionScope()

  public func _shared<T: Sendable>(key: String, _ build: @Sendable () -> T) -> T {
    sharedDependencies.shared(key: key, build)
  }

  static func shared<T: Sendable>(key: String = #function, _ build: @Sendable () -> T) -> T {
    shared.shared(key: key, build)
  }

  private var sharedDependencies = AppScopeStorage()
  private var cancellables = Set<AnyCancellable>()

  private func setupLogging() {
    let logger = DefaultLogger(
      subsystem: defaultLogger.subsystem,
      category: defaultLogger.category,
      fileManager: fileManager,
      userDefaults: sharedUserDefaults)
    /// Override the default global logger. This is not thread safe. By doing it very early in the lifecycle there should be little change of this causing a crash.
    defaultLogger = logger

    settingsService.liveValue(for: \.allowAnonymousAnalytics).sink { [weak logger] allowAnonymousAnalytics in
      if allowAnonymousAnalytics {
        logger?.startExternalLogging()
      } else {
        logger?.stopExternalLogging()
      }
    }.store(in: &cancellables)
  }

}

// MARK: - AppScopeStorage

final class AppScopeStorage: @unchecked Sendable {

  init() { }

  /// Lazily creates a memoized instance of a dependency.
  func shared<T: Sendable>(key: String = #function, _ build: @Sendable () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    if let instance = dependencies[key] as? T { return instance }
    let instance = build()
    dependencies[key] = instance
    return instance
  }

  private var dependencies: [String: Sendable] = [:]

  /// The lock that should be used to synchronize access to the dependencies.
  ///
  /// Recursive lock to allow for shared access to the dependencies from within the `shared` method.
  private let lock = NSRecursiveLock()
}
