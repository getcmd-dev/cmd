// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import SwiftUI

// MARK: - WelcomeView

struct WelcomeView: View {
  let onGetStarted: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      // App icon
      AppLogo()
        .tint(.white)
        .frame(square: 60)
        .foregroundColor(colorScheme.primaryForeground)

      Text("Welcome to cmd")
        .font(.title)
        .fontWeight(.medium)
        .foregroundColor(colorScheme.primaryForeground)

      Text(
        "Let's get you set up.")
        .font(.body)
        .foregroundColor(colorScheme.secondaryForeground)
        .multilineTextAlignment(.center)
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: OnboardingView.Constants.maxTextWidth)
    }
    .frame(width: 600, height: 400, alignment: .top)
  }

  @Environment(\.colorScheme) private var colorScheme

}

#if DEBUG

#Preview("WelcomeView") {
  WelcomeView(onGetStarted: { })
}
#endif
