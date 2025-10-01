// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import SwiftUI

struct BackButton: View {
  let action: () -> Void

  var body: some View {
    HoveredButton(
      action: {
        action()
      },
      onHoverColor: colorScheme.secondarySystemBackground,
      padding: 6,
      cornerRadius: 8)
    {
      HStack(spacing: 6) {
        Image(systemName: "chevron.left")
          .font(.system(size: 12, weight: .medium))
        Text("Back")
      }
    }
  }

  @Environment(\.colorScheme) private var colorScheme

}
