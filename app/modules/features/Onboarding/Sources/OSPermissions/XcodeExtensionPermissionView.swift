// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import SwiftUI

// MARK: - XcodeExtensionPermissionView

struct XcodeExtensionPermissionView: View {
  init(
    isXcodeExtensionPermissionGranted: Bool,
    hasSkippedXcodeExtension: Bool,
    canSkip: Bool,
    skipXcodeExtensionPermissions: @escaping () -> Void,
    requestXcodeExtensionPermission: @escaping () -> Void)
  {
    hasClickedGivePermission = false
    self.hasSkippedXcodeExtension = hasSkippedXcodeExtension
    self.canSkip = canSkip
    self.isXcodeExtensionPermissionGranted = isXcodeExtensionPermissionGranted
    self.skipXcodeExtensionPermissions = skipXcodeExtensionPermissions
    self.requestXcodeExtensionPermission = requestXcodeExtensionPermission
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
        Text("For autocompletion, **cmd** needs to be able to modify source code through Xcode")
          .padding(.leading, 8)
        if isXcodeExtensionPermissionGranted {
          Icon(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .frame(width: 16, height: 16)
            .padding(.leading, 8)
        }
      }.padding()
      if !isXcodeExtensionPermissionGranted {
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

  private let canSkip: Bool
  private let hasSkippedXcodeExtension: Bool

  private let isXcodeExtensionPermissionGranted: Bool

  private let skipXcodeExtensionPermissions: () -> Void
  private let requestXcodeExtensionPermission: () -> Void

  private var xcodeIcon: NSImage? {
    guard let svgPath = Bundle.module.path(forResource: "Xcode", ofType: "svg") else {
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
          requestXcodeExtensionPermission()
          hasClickedGivePermission = true
        },
        onHoverColor: colorScheme.tertiarySystemBackground,
        backgroundColor: colorScheme.secondarySystemBackground,
        padding: 6,
        cornerRadius: 8)
      {
        Text("Give permissions")
      }
      if canSkip {
        HoveredButton(
          action: {
            skipXcodeExtensionPermissions()
          },
          onHoverColor: colorScheme.tertiarySystemBackground,
          backgroundColor: colorScheme.secondarySystemBackground,
          padding: 6,
          cornerRadius: 8,
          isEnable: !hasSkippedXcodeExtension)
        {
          Text(hasSkippedXcodeExtension ? "Skipped" : "Skip")
        }
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
        "Follow the pop up, or navigate to \(Text("[**Settings > Login Items & Extensions > Xcode Source Editor (at the bottom)**](x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=com.apple.dt.Xcode.extension.source-editor)")) and allow **cmd**.")
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: OnboardingView.Constants.maxTextWidth, alignment: .leading)

      if canSkip {
        HoveredButton(
          action: {
            skipXcodeExtensionPermissions()
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

}

#if DEBUG

extension XcodeExtensionPermissionView {
  init(hasClickedGivePermission: Bool, isXcodeExtensionPermissionGranted: Bool = false) {
    self.hasClickedGivePermission = hasClickedGivePermission
    hasSkippedXcodeExtension = false
    canSkip = true
    self.isXcodeExtensionPermissionGranted = isXcodeExtensionPermissionGranted
    skipXcodeExtensionPermissions = { }
    requestXcodeExtensionPermission = { }
  }
}

#Preview("XcodeExtensionPermissionView") {
  XcodeExtensionPermissionView(hasClickedGivePermission: false)
}

#Preview("XcodeExtensionPermissionView - waiting for permission") {
  XcodeExtensionPermissionView(hasClickedGivePermission: true)
}
#endif
