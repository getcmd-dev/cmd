// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import AppUpdateServiceInterface
import ConcurrencyFoundation
import Dependencies
import DLS
import PermissionsServiceInterface
import SettingsServiceInterface
import SwiftUI

// MARK: - AboutSettingsView

struct AboutSettingsView: View {
  @Binding var allowAnonymousAnalytics: Bool
  @Binding var automaticallyCheckForUpdates: Bool
  @Binding var fileEditMode: FileEditMode
  @Binding var launchHostAppWhenXcodeDidActivate: Bool
  @Binding var queueMessagesWhileStreaming: Bool
  @Binding var enablePushNotifications: Bool
  @Bindable var accessibilityPermission: ObservableValue<PermissionStatus>
  @Bindable var xcodeExtensionPermission: ObservableValue<PermissionStatus>
  @Bindable var xcodeAutomationPermission: ObservableValue<PermissionStatus>
  @Bindable var pushNotificationsPermission: ObservableValue<PermissionStatus>

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        // App Info Section
        VStack(alignment: .leading, spacing: 16) {
          Text("App Information")
            .font(.headline)

          VStack(alignment: .leading, spacing: 12) {
            if case .updateAvailable(let appUpdateInfo) = appUpdateService.hasUpdateAvailable.value {
              AppUpdateRow(
                appUpdateInfo: appUpdateInfo,
                onRelaunchTapped: { appUpdateService.relaunch() })
              Divider()
            }
            InfoRow(label: "Version", value: Bundle.main.shortVersion)
            HoveredButton(
              action: { handleCheckForUpdatesTapped() },
              onHoverColor: colorScheme.tertiarySystemBackground,
              backgroundColor: colorScheme.secondarySystemBackground,
              padding: 6,
              isEnable: !isCheckingForUpdates,
              content: {
                HStack(spacing: 6) {
                  if isCheckingForUpdates {
                    ProgressView()
                      .controlSize(.small)
                  }
                  Text(isCheckingForUpdates ? "Checking..." : "Check for Updates")
                }
              })
              .frame(maxWidth: .infinity, alignment: .leading)
            if let status = manualUpdateStatus {
              Text(status.message)
                .font(.caption)
                .foregroundColor(status.kind == .error ? .red : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            InfoRow(label: "Build", value: Bundle.main.version)
            InfoRow(label: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "Unknown")
            #if DEBUG
            InfoRow(label: "Type", value: "DEBUG")
            #endif
            Divider()
            PermissionStatusRow(
              permission: .accessibility,
              permissionsService: permissionsService,
              status: accessibilityPermission)
            Divider()
            PermissionStatusRow(
              permission: .xcodeExtension,
              permissionsService: permissionsService,
              status: xcodeExtensionPermission)
            Divider()
            PermissionStatusRow(
              permission: .xcodeAutomation,
              permissionsService: permissionsService,
              status: xcodeAutomationPermission)
            Divider()
            PermissionStatusRow(
              permission: .pushNotification,
              permissionsService: permissionsService,
              status: pushNotificationsPermission)
            if pushNotificationsPermission.isGranted {
              HStack {
                Text("Enable")
                  .foregroundColor(.secondary)
                Spacer()
                Toggle("", isOn: $enablePushNotifications)
                  .toggleStyle(.switch)
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
                HStack(alignment: .top, spacing: 12) {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(mode.rawValue)
                      .fontWeight(.medium)
                    Text(mode.description)
                      .font(.caption)
                      .foregroundColor(.secondary)
                  }
                  Spacer(minLength: 0)
                  RadioButton(isSelected: fileEditMode == mode) {
                    fileEditMode = mode
                  }
                  .fixedSize()
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

        // Message Queue Section
        VStack(alignment: .leading, spacing: 16) {
          Text("Chat Behavior")
            .font(.headline)

          VStack(alignment: .leading, spacing: 12) {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text("Queue messages while streaming")
                  .fontWeight(.medium)
                Text(
                  "When enabled, new messages sent while the assistant is responding will be queued instead of cancelling the current response")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
              Spacer()
              Toggle("", isOn: $queueMessagesWhileStreaming)
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

        Spacer()
      }
    }
  }

  @State private var isCheckingForUpdates = false
  @State private var manualUpdateStatus: ManualUpdateStatus?
  @Environment(\.colorScheme) private var colorScheme

  @Dependency(\.appUpdateService) private var appUpdateService: AppUpdateService
  @Dependency(\.permissionsService) private var permissionsService: PermissionsService

  private func handleCheckForUpdatesTapped() {
    guard !isCheckingForUpdates else { return }
    if case .updateAvailable(let info) = appUpdateService.hasUpdateAvailable.value {
      manualUpdateStatus = ManualUpdateStatus(
        message: (info?.version)
          .map { "Version \($0) is ready to install. Relaunch to update." }
          ?? "An update is ready to install. Relaunch to update.",
        kind: .info)
      return
    }

    manualUpdateStatus = nil
    isCheckingForUpdates = true
    let autoChecksEnabled = automaticallyCheckForUpdates

    Task {
      await appUpdateService.checkForUpdates()
      let result = appUpdateService.hasUpdateAvailable.value
      await MainActor.run {
        switch result {
        case .updateAvailable(let info):
          manualUpdateStatus = ManualUpdateStatus(
            message: (info?.version)
              .map { "Version \($0) is ready to install. Relaunch to update." }
              ?? "An update is ready to install. Relaunch to update.",
            kind: .info)

        case .noUpdateAvailable:
          manualUpdateStatus = ManualUpdateStatus(
            message: "You're up to date.",
            kind: .info)
        }

        if autoChecksEnabled, case .noUpdateAvailable = result {
          appUpdateService.checkForUpdatesContinously()
        }

        isCheckingForUpdates = false
      }
    }
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

// MARK: - ManualUpdateStatus

private struct ManualUpdateStatus: Equatable {
  enum Kind {
    case info
    case error
  }

  let message: String
  let kind: Kind
}

// MARK: - PermissionStatusRow

private struct PermissionStatusRow: View {
  let permission: Permission
  let permissionsService: PermissionsService
  @Bindable var status: ObservableValue<PermissionStatus>

  var body: some View {
    HStack {
      PlainLink(permissionLabel, action: {
        permissionsService.request(permission: permission)
      })
      .foregroundColor(.secondary)
      Spacer()
      Text(statusText)
        .fontWeight(.medium)
        .foregroundColor(statusColor)
    }
  }

  private var permissionLabel: String {
    switch permission {
    case .accessibility:
      "Accessibility Permission"
    case .xcodeExtension:
      "Xcode Extension Permission"
    case .pushNotification:
      "Push Notification Permission"
    case .xcodeAutomation:
      "Xcode Preference Management"
    }
  }

  private var statusText: String {
    status.isGranted ? "Granted" : "Not granted"
  }

  private var statusColor: Color {
    status.isGranted ? .green : .red
  }
}
