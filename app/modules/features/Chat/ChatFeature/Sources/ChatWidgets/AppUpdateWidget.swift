// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppUpdateServiceInterface
import ConcurrencyFoundation
import Dependencies
import DLS
import SwiftUI

// MARK: - AppUpdateWidget

struct AppUpdateWidget: View {
  init() {
    @Dependency(\.appUpdateService) var appUpdateService
    let availableAppUpdate = appUpdateService.hasUpdateAvailable
    self.availableAppUpdate = ObservableValue(availableAppUpdate.eraseToAnyPublisher(), initial: availableAppUpdate.currentValue)
  }

  var body: some View {
    if
      case .updateAvailable(let appUpdateInfo) = availableAppUpdate.value,
      !appUpdateService.isUpdateIgnored(appUpdateInfo)
    {
      VisibleAppUpdateWidget(
        appUpdateInfo: appUpdateInfo,
        onRelaunchTapped: { appUpdateService.relaunch() },
        onIgnoreTapped: { appUpdateService.ignore(update: appUpdateInfo) })
    }
  }

  @Bindable private var availableAppUpdate: ObservableValue<AppUpdateResult>

  @Dependency(\.appUpdateService) private var appUpdateService

}

// MARK: - VisibleAppUpdateWidget

struct VisibleAppUpdateWidget: View {
  init(
    appUpdateInfo: AppUpdateInfo?,
    onRelaunchTapped: @escaping () -> Void,
    onIgnoreTapped: @escaping () -> Void)
  {
    self.appUpdateInfo = appUpdateInfo
    self.onRelaunchTapped = onRelaunchTapped
    self.onIgnoreTapped = onIgnoreTapped
    currentAppVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
  }

  var body: some View {
    if !hasIgnoredUpdate {
      VStack(alignment: .leading) {
        HStack {
          Text("Update available")
            .font(.headline)
            .padding(.bottom, 2)
          Spacer()
          IconButton(action: {
            onIgnoreTapped()
            hasIgnoredUpdate = true
          }, systemName: "xmark")
            .frame(width: 12, height: 12)
        }
        if let appUpdateInfo {
          Text("Version: \(appUpdateInfo.version) is now available.")
          if let currentAppVersion {
            Text("Current: \(currentAppVersion)")
              .font(.caption)
          }
        }
        if let releaseNotesURL = appUpdateInfo?.releaseNotesURL {
          Link("Release Notes", destination: releaseNotesURL)
        }
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
          .frame(maxWidth: .infinity, alignment: .center)
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .with(cornerRadius: 6, borderColor: colorScheme.textAreaBorderColor)
      .padding()
    }
  }

  @State private var hasIgnoredUpdate = false
  @Environment(\.colorScheme) private var colorScheme

  private let appUpdateInfo: AppUpdateInfo?
  private let onRelaunchTapped: () -> Void
  private let onIgnoreTapped: () -> Void
  private let currentAppVersion: String?

}
