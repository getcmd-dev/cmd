// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Dependencies
import DLS
import FoundationInterfaces
import LocalServerServiceInterface
import LoggingServiceInterface
import SwiftUI

// MARK: - InternalSettingsView

struct InternalSettingsView: View {
  @Binding var repeatLastLLMInteraction: Bool
  @Binding var showOnboardingScreenAgain: Bool
  @Binding var pointReleaseXcodeExtensionToDebugApp: Bool
  @Binding var showInternalSettingsInRelease: Bool
  @Binding var defaultChatPositionIsInverted: Bool
  @Binding var enableAnalyticsAndCrashReporting: Bool
  @Binding var enableNetworkProxy: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(spacing: 16) {
        InternalSettingsRow("Show internal settings in Debug app", value: $showInternalSettingsInRelease)

        InternalSettingsRow(
          "Repeat last LLM interaction",
          caption: "Enable for debugging LLM responses",
          value: $repeatLastLLMInteraction)

        InternalSettingsRow(
          "Show onboarding again",
          caption: "Show onboarding flow at next app launch",
          value: $showOnboardingScreenAgain)

        InternalSettingsRow(
          "Point Release Xcode Extension to Debug App",
          caption: "Use the debug version of the extension for development",
          value: $pointReleaseXcodeExtensionToDebugApp)

        InternalSettingsRow(
          "Invert the default chat position",
          caption: "Useful when using both the Debug and Release apps to avoid overlaps",
          value: $defaultChatPositionIsInverted)

        InternalSettingsRow(
          "Enable network proxy",
          caption: "Proxy network requests through a local proxy server",
          value: $enableNetworkProxy)

        #if DEBUG
        InternalSettingsRow(
          "Enable analytics and crash reporting",
          caption: "Send usage data and crash reports for debugging",
          value: $enableAnalyticsAndCrashReporting)
        #endif

        HoveredButton(
          action: {
            Task {
              let message = "test error \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")"
              defaultLogger.error(AppError(message))
              try await Task.sleep(nanoseconds: 1_000_000_000)
              let arr = [Int]()
              _ = arr[100]
            }
          },
          onHoverColor: colorScheme.tertiarySystemBackground,
          backgroundColor: colorScheme.secondarySystemBackground,
          padding: 6,
          cornerRadius: 8,
          content: { Text("Crash the app (out of bound)") })

        HoveredButton(
          action: {
            Task {
              let message = "test error \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")"
              defaultLogger.error(AppError(message))
              try await Task.sleep(nanoseconds: 1_000_000_000)
              fatalError(message)
            }
          },
          onHoverColor: colorScheme.tertiarySystemBackground,
          backgroundColor: colorScheme.secondarySystemBackground,
          padding: 6,
          cornerRadius: 8,
          content: { Text("Crash the app (fatal error)") })

        HoveredButton(
          action: {
            Task {
              _ = try? await server.getRequest(path: "error")
            }
          },
          onHoverColor: colorScheme.tertiarySystemBackground,
          backgroundColor: colorScheme.secondarySystemBackground,
          padding: 6,
          cornerRadius: 8,
          content: { Text("Create server error") })
      }
      .padding(16)
      .background(Color(NSColor.controlBackgroundColor))
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }

    Spacer()
  }

  @Environment(\.colorScheme) private var colorScheme

  @Dependency(\.userDefaults) private var userDefaults

  @Dependency(\.localServer) private var server
}

// MARK: - InternalSettingsRow

struct InternalSettingsRow: View {
  init(_ text: String, caption: String? = nil, value: Binding<Bool>) {
    self.text = text
    self.caption = caption
    _value = value
  }

  @Binding var value: Bool

  let text: String
  let caption: String?

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(text)
        if let caption {
          Text(caption)
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      Spacer()
      Toggle("", isOn: $value)
        .toggleStyle(.switch)
    }
  }
}
