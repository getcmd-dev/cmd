// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - DisabledOverlay

extension View {
  /// Applies a disabled overlay that desaturates the content and blocks interactions
  /// - Parameter isDisabled: Whether the view should be disabled
  /// - Returns: A view with the disabled overlay applied when isDisabled is true
  func disabledOverlay(isDisabled: Bool) -> some View {
    overlay {
      if isDisabled {
        Color.clear
          .contentShape(Rectangle())
          .allowsHitTesting(true)
      }
    }
    .grayscale(isDisabled ? 1 : 0)
    .opacity(isDisabled ? 0.4 : 1)
  }
}
