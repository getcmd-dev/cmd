// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import DLS
import SwiftUI

// MARK: - AccessibilityPermissionView

struct AccessibilityPermissionView: View {

  init(
    isAccessibilityPermissionGranted: Bool,
    requestAccessibilityPermission: @escaping () -> Void)
  {
    hasClickedGivePermission = false
    self.isAccessibilityPermissionGranted = isAccessibilityPermissionGranted
    self.requestAccessibilityPermission = requestAccessibilityPermission
  }

  var body: some View {
    VStack(alignment: .leading) {
      HStack(spacing: 0) {
        Icon(systemName: "accessibility")
          .frame(width: 30, height: 30)
          .foregroundStyle(.white)
          .padding(5)
          .background(.blue)
          .with(cornerRadius: 8)
          .padding(.trailing, 8)
        Text("**cmd** needs accessibility permissions to interact with Xcode")
        if isAccessibilityPermissionGranted {
          Icon(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .frame(width: 16, height: 16)
            .padding(.leading, 8)
        }
      }.padding()
      if !isAccessibilityPermissionGranted {
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

  private let isAccessibilityPermissionGranted: Bool

  private let requestAccessibilityPermission: () -> Void

  @ViewBuilder
  private var askForPermissionView: some View {
    HStack {
      Spacer(minLength: 0)
      HoveredButton(
        action: {
          requestAccessibilityPermission()
          hasClickedGivePermission = true
        },
        onHoverColor: colorScheme.tertiarySystemBackground,
        backgroundColor: colorScheme.secondarySystemBackground,
        padding: 6,
        cornerRadius: 8)
      {
        Text("Give permissions")
      }
      Spacer(minLength: 0)
    }
  }

  @ViewBuilder
  private var waitingForPermissionView: some View {
    VStack(alignment: .leading) {
      HStack(spacing: 0) {
        Text("Waiting for permissions")
        ThreeDotsLoadingAnimation()
      }
      .padding(.bottom, 10)

      Text(
        "Follow the pop up, or navigate to \(Text("[**Settings > Privacy & Security > Accessibility**](x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility)")) and allow **cmd**.")
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

}

#if DEBUG
extension AccessibilityPermissionView {
  init(hasClickedGivePermission: Bool, isAccessibilityPermissionGranted: Bool = false) {
    _hasClickedGivePermission = .init(initialValue: hasClickedGivePermission)
    self.isAccessibilityPermissionGranted = isAccessibilityPermissionGranted
    requestAccessibilityPermission = { }
  }

}

#Preview("AccessibilityPermissionView") {
  AccessibilityPermissionView(hasClickedGivePermission: false)
}

#Preview("AccessibilityPermissionView - waiting for permission") {
  AccessibilityPermissionView(hasClickedGivePermission: true)
}
#endif
