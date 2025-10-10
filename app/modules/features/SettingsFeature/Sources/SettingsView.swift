// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import RoutingFoundation
import SettingsServiceInterface
import SwiftUI

// MARK: - SettingsView

public struct SettingsView: View {
  public init(viewModel: SettingsViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    SettingsLandingView(
      onNavigate: { section in
        router.push(view(for: section))
      },
      hasAvailableModels: !viewModel.llmSettings.availableModels.isEmpty,
      showInternalSettingsInRelease: viewModel.showInternalSettingsInRelease)
      .padding(.horizontal, Constants.horizontalPadding)
      .padding(.vertical, Constants.verticalPadding)
  }

  private enum Constants {
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 16
  }

  @Environment(Router.self) private var router

  @Environment(\.colorScheme) private var colorScheme
  @Bindable private var viewModel: SettingsViewModel

  @ViewBuilder
  private func view(for section: SettingsSection) -> some View {
    VStack(spacing: 0) {
      // Header with icon and title
      HStack(spacing: 8) {
        Image(systemName: section.iconName)
          .frame(width: 16, height: 16)
        Text(section.title)
          .font(.title2)
          .fontWeight(.medium)
        Spacer()
      }
      .padding(.top, 16)
      .padding(.bottom, 20)

      switch section {
      case .providers:
        AIProvidersView(viewModel: viewModel.llmSettings)

      case .models:
        ModelsView(viewModel: viewModel.llmSettings)

      case .chatModes:
        ChatModeView(customInstructions: $viewModel.customInstructions)

      case .tools:
        ToolsConfigurationView(viewModel: viewModel.toolConfigurationViewModel)

      case .mcp:
        MCPSettingsView(mcpServers: $viewModel.mcpServers)

      case .keyboardShortcuts:
        KeyboardShortcutsSettingsView(keyboardShortcuts: $viewModel.keyboardShortcuts)

      case .userDefinedXcodeShortcuts:
        UserDefinedXcodeShortcutsSettingsView(userDefinedXcodeShortcuts: $viewModel.userDefinedXcodeShortcuts)

      case .internalSettings:
        InternalSettingsView(
          repeatLastLLMInteraction: $viewModel.repeatLastLLMInteraction,
          showOnboardingScreenAgain: $viewModel.showOnboardingScreenAgain,
          pointReleaseXcodeExtensionToDebugApp: $viewModel.pointReleaseXcodeExtensionToDebugApp,
          showInternalSettingsInRelease: $viewModel.showInternalSettingsInRelease,
          defaultChatPositionIsInverted: $viewModel.defaultChatPositionIsInverted,
          enableAnalyticsAndCrashReporting: $viewModel.enableAnalyticsAndCrashReporting,
          enableNetworkProxy: $viewModel.enableNetworkProxy,
          showToolInputCopyButtonInRelease: $viewModel.showToolInputCopyButtonInRelease,
          defaultLogLevel: $viewModel.defaultLogLevel)

      case .about:
        AboutSettingsView(
          allowAnonymousAnalytics: $viewModel.allowAnonymousAnalytics,
          automaticallyCheckForUpdates: $viewModel.automaticallyCheckForUpdates,
          fileEditMode: $viewModel.fileEditMode,
          launchHostAppWhenXcodeDidActivate: $viewModel.launchHostAppWhenXcodeDidActivate)
      }
    }
    .padding(.horizontal, Constants.horizontalPadding)
    .padding(.vertical, Constants.verticalPadding)
  }

}

// MARK: - SettingsSection

private enum SettingsSection: String, Identifiable, CaseIterable {
  case providers
  case models
  case chatModes
  case tools
  case mcp
  case keyboardShortcuts
  case userDefinedXcodeShortcuts
  case internalSettings
  case about

  var id: String { rawValue }

  var title: String {
    switch self {
    case .providers:
      "Providers"
    case .models:
      "Models"
    case .tools:
      "Tools"
    case .mcp:
      "MCP (Preview)"
    case .chatModes:
      "Chat Modes"
    case .keyboardShortcuts:
      "Keyboard Shortcuts"
    case .userDefinedXcodeShortcuts:
      "Xcode Shortcuts"
    case .internalSettings:
      "Internal Settings"
    case .about:
      "About"
    }
  }

  var iconName: String {
    switch self {
    case .providers:
      "key"
    case .models:
      "cpu"
    case .chatModes:
      "text.bubble"
    case .tools:
      "wrench.and.screwdriver"
    case .mcp:
      "network"
    case .keyboardShortcuts:
      "keyboard"
    case .userDefinedXcodeShortcuts:
      "command"
    case .internalSettings:
      "slider.horizontal.3"
    case .about:
      "info.circle"
    }
  }
}

// MARK: - SettingsLandingView

private struct SettingsLandingView: View {
  let onNavigate: (SettingsSection) -> Void
  let hasAvailableModels: Bool
  let showInternalSettingsInRelease: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      HStack {
        Icon(systemName: "gearshape")
          .frame(width: 16, height: 16)

        Text("Settings")
          .font(.title2)
          .fontWeight(.medium)
        Spacer()
      }
      .padding(.vertical, 16)

      // Settings cards
      ScrollView {
        VStack(spacing: 16) {
          SettingsCard(
            section: .providers,
            description: "Manage API keys and setup LLM providers",
            action: onNavigate)

          if hasAvailableModels {
            SettingsCard(
              section: .models,
              description: "Models configuration",
              action: onNavigate)
          }

          SettingsCard(
            section: .chatModes,
            description: "Configure chat modes (Ask, Agent) and provide specific instructions",
            action: onNavigate)

          SettingsCard(
            section: .tools,
            description: "Manage tool permissions and approval settings",
            action: onNavigate)

          SettingsCard(
            section: .mcp,
            description: "Configure Model Context Protocol servers",
            action: onNavigate)

          SettingsCard(
            section: .keyboardShortcuts,
            description: "Configure app keyboard shortcuts",
            action: onNavigate)

          SettingsCard(
            section: .userDefinedXcodeShortcuts,
            description: "Configure new shortcuts that will be available in Xcode",
            action: onNavigate)

          SettingsCard(
            section: .about,
            description: nil,
            action: onNavigate)

          #if DEBUG
          SettingsCard(
            section: .internalSettings,
            description: "Custom application settings",
            action: onNavigate)
          #else
          if showInternalSettingsInRelease {
            SettingsCard(
              section: .internalSettings,
              description: "Custom application settings",
              action: onNavigate)
          }
          #endif
        }
      }
    }
  }

  @Environment(\.colorScheme) private var colorScheme

}

// MARK: - SettingsCard

private struct SettingsCard: View {
  let section: SettingsSection
  let description: String?
  let action: (SettingsSection) -> Void

  var body: some View {
    Button(action: { action(section) }) {
      HStack(spacing: 16) {
        Image(systemName: section.iconName)
          .font(.system(size: 20))
          .frame(width: 32, height: 32)

        VStack(alignment: .leading, spacing: 4) {
          Text(section.title)
            .font(.headline)
            .foregroundColor(.primary)
          if let description {
            Text(description)
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
        }

        Spacer()

        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.secondary)
      }
      .padding(16)
      .background(Color(NSColor.controlBackgroundColor))
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity)
  }
}
