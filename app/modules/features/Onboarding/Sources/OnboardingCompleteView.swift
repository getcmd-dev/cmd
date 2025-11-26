// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import SwiftUI

// MARK: - OnboardingCompletedView

struct OnboardingCompletedView: View {

  var body: some View {
    VStack(spacing: 16) {
      Text("All Setup")
        .bold()

      Text("When in Xcode, you can now press **⌘ + I** to bring **cmd**")
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: OnboardingView.Constants.maxTextWidth, alignment: .leading)
    }
    .padding()
  }
}

#if DEBUG
#Preview(traits: .sizeThatFitsLayout) {
  OnboardingCompletedView()
    .padding()
}
#endif
