// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

#if DEBUG
extension Binding {
  /// Creates a mutable binding for Swift UI previews.
  ///
  /// This is meant to be used for Swift UI previews, where they could be passed in as an initial value for the view.
  /// This should not be used in production code because every time this is called, it will reset the value.
  @MainActor
  public static func mutable(_ value: Value) -> Self {
    ObservableValue(value).binding
  }
}
#endif
