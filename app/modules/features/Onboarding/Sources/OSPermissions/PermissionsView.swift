// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

struct PermissionsView: View {

  let viewModel: OnboardingViewModel

  var body: some View {
    VStack {
      Text("Permissions")
        .font(.headline)
        .padding(.bottom, 8)

      HStack(alignment: .top) {
        VStack(alignment: .leading) {
          AccessibilityPermissionView(
            isAccessibilityPermissionGranted: viewModel.isAccessibilityPermissionGranted,
            requestAccessibilityPermission: viewModel.handleRequestAccessibilityPermission)

          if viewModel.isAccessibilityPermissionGranted {
            XcodeExtensionPermissionView(
              isXcodeExtensionPermissionGranted: viewModel.isXcodeExtensionPermissionGranted,
              hasSkippedXcodeExtension: viewModel.hasSkippedXcodeExtension, canSkip: true,
              skipXcodeExtensionPermissions: {
                viewModel.handleSkipXcodeExtensionPermissions()
              },
              requestXcodeExtensionPermission: viewModel.handleRequestXcodeExtensionPermission)

            if viewModel.isXcodeExtensionPermissionGranted || viewModel.hasSkippedXcodeExtension {
              XcodeAIProviderPermissionView(
                isXcodeAIProviderPermissionGranted: viewModel.isXcodeAIProviderPermissionGranted,
                hasSkippedXcodeAIProvider: viewModel.hasSkippedXcodeAIProviderPermissions,
                skipXcodeAIProviderPermissions: {
                  viewModel.handleSkipXcodeAIProviderPermissions()
                },
                requestXcodeAIIntegrationPermission: viewModel.requestXcodeAIIntegrationPermission)
            }
          }
        }
      }
    }
  }

}
