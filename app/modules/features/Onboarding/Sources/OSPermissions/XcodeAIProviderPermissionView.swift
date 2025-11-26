// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import SwiftUI

// MARK: - XcodeAIProviderPermissionView

struct XcodeAIProviderPermissionView: View {
  init(
    isXcodeAIProviderPermissionGranted: Bool,
    hasSkippedXcodeAIProvider: Bool,
    skipXcodeAIProviderPermissions: @escaping () -> Void,
    requestXcodeAIIntegrationPermission: @escaping () -> Void)
  {
    hasClickedGivePermission = false
    self.hasSkippedXcodeAIProvider = hasSkippedXcodeAIProvider
    self.isXcodeAIProviderPermissionGranted = isXcodeAIProviderPermissionGranted
    self.skipXcodeAIProviderPermissions = skipXcodeAIProviderPermissions
    self.requestXcodeAIIntegrationPermission = requestXcodeAIIntegrationPermission
  }

  var body: some View {
    VStack(alignment: .leading) {
      HStack(spacing: 0) {
        if let xcodeIcon {
          Image(nsImage: xcodeIcon)
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .frame(width: 40, height: 40)
        } else {
          Icon(systemName: "hammer")
            .frame(width: 30, height: 30)
            .foregroundStyle(.primary)
            .padding(5)
            .background(.blue)
            .with(cornerRadius: 8)
            .padding(.trailing, 8)
        }
        Text("Allow **cmd** to manage Xcode's AI configuration to integrate with the Xcode's AI interface.")
          .padding(.leading, 8)
        if isXcodeAIProviderPermissionGranted {
          Icon(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .frame(width: 16, height: 16)
            .padding(.leading, 8)
        }
      }.padding()
      if !isXcodeAIProviderPermissionGranted {
        if !hasClickedGivePermission {
          askForPermissionView
        } else {
          waitingForPermissionView
        }
      }
    }
  }

  @Environment(\.colorScheme) private var colorScheme
  @State private var hasClickedGivePermission = false

  private let hasSkippedXcodeAIProvider: Bool

  private let isXcodeAIProviderPermissionGranted: Bool

  private let skipXcodeAIProviderPermissions: () -> Void
  private let requestXcodeAIIntegrationPermission: () -> Void

  private var xcodeIcon: NSImage? {
    guard let svgPath = Bundle.module.path(forResource: "Xcode-intelligence", ofType: "png") else {
      return nil
    }
    return try? SVGImageLoader.svg(atPath: svgPath)
  }

  @ViewBuilder
  private var askForPermissionView: some View {
    HStack {
      Spacer()
      HoveredButton(
        action: {
          requestXcodeAIIntegrationPermission()
          hasClickedGivePermission = true
        },
        onHoverColor: colorScheme.tertiarySystemBackground,
        backgroundColor: colorScheme.secondarySystemBackground,
        padding: 6,
        cornerRadius: 8)
      {
        Text("Give permissions")
      }
      HoveredButton(
        action: {
          skipXcodeAIProviderPermissions()
        },
        onHoverColor: colorScheme.tertiarySystemBackground,
        backgroundColor: colorScheme.secondarySystemBackground,
        padding: 6,
        cornerRadius: 8,
        isEnable: !hasSkippedXcodeAIProvider)
      {
        Text(hasSkippedXcodeAIProvider ? "Skipped" : "Skip")
      }
      Spacer()
    }
  }

  @ViewBuilder
  private var waitingForPermissionView: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 0) {
        Text("Waiting for permissions")
        ThreeDotsLoadingAnimation()
      }

      Text(
        "Follow the pop up to allow **cmd** to integrate with Xcode's AI interface. This enables automatic management of the AI provider integration.")
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: OnboardingView.Constants.maxTextWidth, alignment: .leading)

      HoveredButton(
        action: {
          skipXcodeAIProviderPermissions()
        },
        onHoverColor: colorScheme.tertiarySystemBackground,
        backgroundColor: colorScheme.secondarySystemBackground,
        padding: 6,
        cornerRadius: 8)
      {
        Text("Skip")
      }
    }
  }

}

#if DEBUG

extension XcodeAIProviderPermissionView {
  init(hasClickedGivePermission: Bool, isXcodeAIProviderPermissionGranted: Bool = false) {
    self.hasClickedGivePermission = hasClickedGivePermission
    hasSkippedXcodeAIProvider = false
    self.isXcodeAIProviderPermissionGranted = isXcodeAIProviderPermissionGranted
    skipXcodeAIProviderPermissions = { }
    requestXcodeAIIntegrationPermission = { }
  }
}

#Preview("XcodeAIProviderPermissionView") {
  XcodeAIProviderPermissionView(hasClickedGivePermission: false)
}

#Preview("XcodeAIProviderPermissionView - waiting for permission") {
  XcodeAIProviderPermissionView(hasClickedGivePermission: true)
}
#endif
