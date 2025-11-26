// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import DLS
import RoutingFoundation
import SettingsFeatureInterface
import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
  /// Create a view to guide the user through a few onboarding steps.
  init(
    viewModel: OnboardingViewModel)
  {
    self.viewModel = viewModel
  }

  enum Constants {
    static let maxTextWidth: CGFloat = 600
  }

  var body: some View {
    VStack {
      Group {
        switch viewModel.currentStep {
        case .welcome:
          WelcomeView(onGetStarted: {
            viewModel.handleMoveToNextStep()
          })
          .readingSize($referenceViewSize)

        case .osPermissions:
          PermissionsView(viewModel: viewModel)

        case .providersSetup:
          llmProviderSetupView

        case .autocompletion:
          autocompletionSetupView

        case .setupComplete:
          OnboardingCompletedView()
        }
      }
      .frame(width: referenceViewSize.width, height: referenceViewSize.height, alignment: .top)
      .padding(40)

      HStack {
        if viewModel.currentStep != .welcome {
          HoveredButton(
            action: {
              viewModel.handleMoveToPreviousStep()
            },
            padding: 8,
            cornerRadius: 4)
          {
            Text("Back")
              .foregroundColor(colorScheme.secondaryForeground)
          }
        }
        Spacer(minLength: 0)
        HoveredButton(
          action: {
            viewModel.handleMoveToNextStep()
          },
          onHoverColor: nextButtonHoverColor,
          backgroundColor: nextButtonBackgroundColor,
          padding: 8,
          cornerRadius: 4,
          isEnable: viewModel.canGoToNextStep)
        {
          Text(nextButtonLabel)
            .foregroundColor(.white)
        }
      }
      .padding(.horizontal, 16)
      .frame(maxWidth: .infinity)

      HStack(spacing: 12) {
        ForEach(OnboardingStep.allCases.enumerated(), id: \.offset) { _, step in
          Circle()
            .fill(step == viewModel.currentStep ? Color.accentColor : Color.gray.opacity(0.5))
            .frame(square: 7)
        }
      }
      .padding(.bottom, 10)
    }
    .padding(20)
    .with(backgroundColor: colorScheme.primaryBackground)
  }

  @State private var referenceViewSize = CGSize.zero

  @Environment(\.colorScheme) private var colorScheme

  @Bindable private var viewModel: OnboardingViewModel

  @Environment(Router.self) private var router

  private var nextButtonLabel: String {
    if viewModel.currentStep == .setupComplete {
      return "Start using cmd"
    }
    if viewModel.currentStep == .autocompletion, !viewModel.hasSetupAutocompletionProvider {
      return "Skip for now"
    }
    return "Next"
  }

  private var nextButtonBackgroundColor: Color {
    if viewModel.currentStep == .autocompletion, !viewModel.hasSetupAutocompletionProvider {
      return colorScheme.secondarySystemBackground
    }
    return viewModel.canGoToNextStep ? .accentColor : colorScheme.secondarySystemBackground
  }

  private var nextButtonHoverColor: Color {
    if viewModel.currentStep == .autocompletion, !viewModel.hasSetupAutocompletionProvider {
      return colorScheme.tertiarySystemBackground
    }
    return viewModel.canGoToNextStep ? .accentColor.opacity(0.8) : nextButtonBackgroundColor
  }

  @ViewBuilder
  private var llmProviderSetupView: some View {
    VStack {
      Text("AI Provider")
        .font(.headline)
        .padding(.bottom, 8)

      HStack {
        Text(
          "Configure at least one AI provider to get started. You can always add or change providers later in the app settings.")
          .lineLimit(nil)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      AnyView(router.embed(route: AIProviderSettingsRoute()))
    }
  }

  @ViewBuilder
  private var autocompletionSetupView: some View {
    VStack(alignment: .leading) {
      Text("Autocompletion")
        .font(.headline)
        .padding(.bottom, 8)

      if !viewModel.isXcodeExtensionPermissionGranted {
        Text("Xcode Extension permission is required to enable autocompletion.")

        XcodeExtensionPermissionView(
          isXcodeExtensionPermissionGranted: viewModel.isXcodeExtensionPermissionGranted,
          hasSkippedXcodeExtension: viewModel.hasSkippedXcodeExtension,
          canSkip: false,
          skipXcodeExtensionPermissions: {
            viewModel.handleSkipXcodeExtensionPermissions()
          }, requestXcodeExtensionPermission: viewModel.handleRequestXcodeExtensionPermission)
      } else {
        HStack {
          Text(
            "To use autocompletion, you need to configure one of the AI provider below:")
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        AnyView(router.embed(route: AutocompletionProviderSettingsRoute(showDetailedSettings: false)))
      }
    }
  }

}
