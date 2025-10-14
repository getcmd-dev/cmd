// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import ThreadSafe

#if DEBUG
@ThreadSafe
public final class MockAppUpdateService: AppUpdateService {

  public init(hasUpdateAvailable: AppUpdateResult = .noUpdateAvailable) {
    _hasUpdateAvailable = .init(hasUpdateAvailable)
  }

  public var onRelaunch: (@Sendable () -> Void)?
  public var onStopCheckingForUpdates: (@Sendable () -> Void)?
  public var onCheckForUpdatesContinuously: (@Sendable () -> Void)?
  public var onIgnoreUpdate: (@Sendable (AppUpdateInfo?) -> Void)?
  public var onIsUpdateIgnored: (@Sendable (AppUpdateInfo?) -> Bool)?

  public var hasUpdateAvailable: ReadonlyCurrentValueSubject<AppUpdateResult, Never> {
    _hasUpdateAvailable.readonly()
  }

  public func relaunch() {
    onRelaunch?()
  }

  public func stopCheckingForUpdates() {
    onStopCheckingForUpdates?()
  }

  public func checkForUpdatesContinously() {
    onCheckForUpdatesContinuously?()
  }

  public func ignore(update: AppUpdateInfo?) {
    onIgnoreUpdate?(update)
  }

  public func isUpdateIgnored(_ update: AppUpdateInfo?) -> Bool {
    onIsUpdateIgnored?(update) ?? false
  }

  public func setUpdateAvailable(_ result: AppUpdateResult) {
    _hasUpdateAvailable.send(result)
  }

  private let _hasUpdateAvailable: CurrentValueSubject<AppUpdateResult, Never>

}
#endif
