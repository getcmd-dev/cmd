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
      HStack(alignment: .center, spacing: 0) {
        VStack(alignment: .leading, spacing: 8) {
          Text("New update available")
          Text("Restart to use the latest.")
            .font(.system(size: .bodySize, weight: .light))
        }

        Spacer(minLength: 0)
        HStack(spacing: 8) {
          HoveredButton(
            action: {
              _ = URL(string: "https://getcmd.dev/changelog").map(NSWorkspace.shared.open)
            },
            onHoverColor: colorScheme.tertiarySystemBackground,
            backgroundColor: .clear,
            padding: 8,
            content: {
              Text("See changes")
            })
            .with(cornerRadius: 6, borderColor: colorScheme.textAreaBorderColor)

          HoveredButton(
            action: {
              onRelaunchTapped()
            },
            onHoverColor: colorScheme.tertiarySystemBackground.inverted,
            backgroundColor: colorScheme.secondarySystemBackground.inverted,
            padding: 8,
            content: {
              Text("Restart")
                .foregroundColor(.primary.inverted)
            })
            .with(cornerRadius: 6)
        }
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .with(
        cornerRadius: 8,
        backgroundColor: colorScheme.primaryBackground,
        borderColor: colorScheme.textAreaBorderColor)
      .overlay(alignment: .topLeading) {
        IconButton(action: {
          onIgnoreTapped()
          hasIgnoredUpdate = true
        }, systemName: "xmark")
          .frame(width: 10, height: 10)
          .padding(4)
          .background(colorScheme.primaryBackground)
          .clipShape(Circle())
          .overlay(Circle().stroke(colorScheme.textAreaBorderColor, lineWidth: 1))
          .offset(x: -6, y: -6)
      }
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
