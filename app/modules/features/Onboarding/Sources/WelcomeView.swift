// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import SwiftUI

// MARK: - WelcomeView

struct WelcomeView: View {
  let onGetStarted: () -> Void

  var body: some View {
    VStack(spacing: 40) {
      VStack(spacing: 24) {
        // App icon
        RoundedRectangle(cornerRadius: 16)
          .fill(Color.blue)
          .frame(width: 80, height: 80)
          .overlay(
            AppIcon()
              .tint(.white)
              .frame(square: 60)
              .foregroundColor(colorScheme.primaryForeground))

        VStack(spacing: 16) {
          Text("Welcome to ")
            .font(.system(size: 20))
            .fontWeight(.medium)
            .foregroundColor(colorScheme.primaryForeground)
            + Text("cmd")
            .font(.system(size: 20, design: .monospaced))
            .fontWeight(.medium)
            .foregroundColor(colorScheme.primaryForeground.opacity(0.5))

          Text(
            "Your coding assistant for Xcode. Enhance your development workflow with AI-powered code suggestions.  Let agents automate the busy work so you can focus on what matters most.\n\nIt's all open source and local.")
            .font(.body)
            .foregroundColor(colorScheme.secondaryForeground)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: OnboardingView.Constants.maxTextWidth)
        }
      }

      HStack(spacing: 24) {
        FeatureCard(
          icon: "sparkles",
          title: "AI-Powered",
          description: "State-of-the-art inteligence from the best language models with robust agentic capabilities.")

        FeatureCard(
          icon: "lock.open",
          title: "Open Source",
          description: "Fully open source and transparent. Contribute to the future of iOS & MacOS development.")

        FeatureCard(
          icon: "bolt",
          title: "Xcode Native",
          description: "Seamlessly integrated into your Xcode workflow. No need to use another IDE. **cmd** works with Xcode 26's AI chat.")

        FeatureCard(
          icon: "shield",
          title: "Local development",
          description: "**cmd** runs locally on your computer. No intermediary services, no cloud based third parties to trust.")
      }

      HoveredButton(
        action: onGetStarted,
        onHoverColor: .accentColor.opacity(0.8),
        backgroundColor: .accentColor,
        padding: 16,
        cornerRadius: 12)
      {
        Text("Get Started")
          .font(.headline)
          .foregroundColor(.white)
          .lineLimit(1)
      }
    }
  }

  @Environment(\.colorScheme) private var colorScheme

}

// MARK: - FeatureCard

private struct FeatureCard: View {
  let icon: String
  let title: String
  let description: String

  var body: some View {
    VStack(spacing: 16) {
      Icon(systemName: icon).frame(width: 24, height: 24)

      VStack(spacing: 8) {
        Text(title)
          .font(.headline)
          .foregroundColor(colorScheme.primaryForeground)

        Text(.init(description))
          .font(.body)
          .foregroundColor(colorScheme.secondaryForeground)
          .multilineTextAlignment(.center)
          .lineLimit(nil)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 0)
    }
    .padding(24)
    .frame(width: 200)
    .background(colorScheme.secondarySystemBackground)
    .cornerRadius(16)
  }

  @Environment(\.colorScheme) private var colorScheme

}

#if DEBUG

#Preview("WelcomeView") {
  WelcomeView(onGetStarted: { })
}
#endif
