// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies

// MARK: - KeyboardShortcutServiceDependencyKey

public final class KeyboardShortcutServiceDependencyKey: TestDependencyKey {
  #if DEBUG
  public static let testValue: KeyboardShortcutService = MockKeyboardShortcutService()
  #else
  public static let testValue: KeyboardShortcutService = () as! KeyboardShortcutService
  #endif
}

extension DependencyValues {
  public var keyboardShortcutService: KeyboardShortcutService {
    get { self[KeyboardShortcutServiceDependencyKey.self] }
    set { self[KeyboardShortcutServiceDependencyKey.self] = newValue }
  }
}
