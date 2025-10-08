// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppUpdateServiceInterface
import Dependencies
import DLS
import SettingsServiceInterface
import SwiftUI

// MARK: - AboutSettingsView

struct AboutSettingsView: View {
  @Binding var allowAnonymousAnalytics: Bool
  @Binding var automaticallyCheckForUpdates: Bool
  @Binding var fileEditMode: FileEditMode
  @Binding var launchHostAppWhenXcodeDidActivate: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      // App Info Section
      VStack(alignment: .leading, spacing: 16) {
        Text("App Information")
          .font(.headline)

        VStack(alignment: .leading, spacing: 12) {
          if case .updateAvailable(let appUpdateInfo) = appUpdateService.hasUpdateAvailable.currentValue {
            AppUpdateRow(
              appUpdateInfo: appUpdateInfo,
              onRelaunchTapped: { appUpdateService.relaunch() })
            Divider()
          }
          InfoRow(label: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
          InfoRow(label: "Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
          InfoRow(label: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "Unknown")
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.gray.opacity(0.2), lineWidth: 1))
      }

      // Privacy Section
      VStack(alignment: .leading, spacing: 16) {
        Text("Privacy")
          .font(.headline)

        VStack(spacing: 16) {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Allow anonymous error and usage reporting")
              Text(
                "Help improve command by sending anonymous usage data and error reports. No code, prompts, or personal information is ever sent.")
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $allowAnonymousAnalytics)
              .toggleStyle(.switch)
          }

          Divider()

          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Automatically check for updates")
              Text("Automatically download and install updates in the background when available.")
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $automaticallyCheckForUpdates)
              .toggleStyle(.switch)
          }

          Divider()

          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Launch `cmd` when Xcode becomes active")
              Text(
                "Ensure that `cmd` is running when you use Xcode.")
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $launchHostAppWhenXcodeDidActivate)
              .toggleStyle(.switch)
          }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.gray.opacity(0.2), lineWidth: 1))
      }

      // File Edit Mode Section
      VStack(alignment: .leading, spacing: 16) {
        Text("File Editing")
          .font(.headline)

        VStack(alignment: .leading, spacing: 16) {
          Text("File Edit Mode")
            .fontWeight(.medium)

          VStack(spacing: 12) {
            ForEach(FileEditMode.allCases, id: \.self) { mode in
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text(mode.rawValue)
                    .fontWeight(.medium)
                  Text(mode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                Spacer()
                RadioButton(isSelected: fileEditMode == mode) {
                  fileEditMode = mode
                }
              }
              .contentShape(Rectangle())
              .onTapGesture {
                fileEditMode = mode
              }
            }
          }
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
  }

  @Dependency(\.appUpdateService) private var appUpdateService: AppUpdateService

}

// MARK: - RadioButton

private struct RadioButton: View {
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ZStack {
        Circle()
          .stroke(Color.secondary, lineWidth: 2)
          .frame(width: 16, height: 16)

        if isSelected {
          Circle()
            .fill(Color.accentColor)
            .frame(width: 8, height: 8)
        }
      }
    }
    .buttonStyle(PlainButtonStyle())
  }
}

// MARK: - InfoRow

private struct InfoRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack {
      Text(label)
        .foregroundColor(.secondary)
      Spacer()
      Text(value)
        .fontWeight(.medium)
    }
  }
}

// MARK: - AppUpdateRow

struct AppUpdateRow: View {
  init(
    appUpdateInfo: AppUpdateInfo?,
    onRelaunchTapped: @escaping () -> Void)
  {
    self.appUpdateInfo = appUpdateInfo
    self.onRelaunchTapped = onRelaunchTapped
  }

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text("Update \(versionInfo)available")
          .font(.headline)
          .padding(.bottom, 2)
        if let releaseNotesURL = appUpdateInfo?.releaseNotesURL {
          Link("Release Notes", destination: releaseNotesURL)
        }
      }
      Spacer()
      HoveredButton(
        action: {
          onRelaunchTapped()
        },
        onHoverColor: colorScheme.tertiarySystemBackground,
        backgroundColor: colorScheme.secondarySystemBackground,
        padding: 5,
        content: {
          Text("Relaunch")
        })
    }
  }

  @Environment(\.colorScheme) private var colorScheme

  private let appUpdateInfo: AppUpdateInfo?
  private let onRelaunchTapped: () -> Void

  private var versionInfo: String {
    if let version = appUpdateInfo?.version {
      "\(version) "
    } else {
      ""
    }
  }

}
