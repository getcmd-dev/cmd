// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import DLS
import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
  /// Create a view to guide the user through a few onboarding steps.
  /// - Parameter showLLMProviders: returns a view to configure LLM providers. It receive a closure to call when the user is ready to proceed.
  init(
    viewModel: OnboardingViewModel,
    createLLMProvidersView: @MainActor @escaping (@MainActor @escaping () -> Void) -> AnyView)
  {
    self.viewModel = viewModel
    self.createLLMProvidersView = createLLMProvidersView
  }

  enum Constants {
    static let maxTextWidth: CGFloat = 600
  }

  var body: some View {
    ZStack {
      WelcomeView(onGetStarted: {
        viewModel.handleMoveToNextStep()
      })
      .readingSize($referenceViewSize)
      .isHidden(viewModel.currentStep != .welcome)

      if viewModel.currentStep == .accessibilityPermission || viewModel.currentStep == .xcodeExtensionPermission {
        PermissionsView(viewModel: viewModel)
      } else if viewModel.currentStep == .providersSetup {
        llmProviderSetupView
          .isHidden(viewModel.currentStep != .providersSetup)
      } else if viewModel.currentStep == .setupComplete {
        OnboardingCompletedView(onDone: viewModel.handleMoveToNextStep)
      }
    }
    .frame(height: referenceViewSize.height)
    .padding(40)
    .background(colorScheme.primaryBackground)
  }

  @State private var referenceViewSize = CGSize.zero

  @Environment(\.colorScheme) private var colorScheme

  @Bindable private var viewModel: OnboardingViewModel

  private let createLLMProvidersView: @MainActor (@MainActor @escaping () -> Void) -> AnyView

  @ViewBuilder
  private var llmProviderSetupView: some View {
    VStack {
      Text("2/2 - Configure LLM Providers")
        .font(.headline)
        .padding(.bottom, 8)

      HStack {
        Text(
          "**cmd** is free to use, but you need to bring your own API key. Configure at least one provider below to get started.")
          .lineLimit(nil)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
      }

      createLLMProvidersView {
        viewModel.handleMoveToNextStep()
      }

      if viewModel.canSkipProviderSetup {
        HoveredButton(
          action: {
            viewModel.handleMoveToNextStep()
          },
          onHoverColor: .accentColor.opacity(0.8),
          backgroundColor: .accentColor,
          padding: 8,
          cornerRadius: 6)
        {
          Text("Next")
            .font(.headline)
            .foregroundColor(.white)
            .lineLimit(1)
        }
      }
      Spacer(minLength: 0)
    }
  }

}
