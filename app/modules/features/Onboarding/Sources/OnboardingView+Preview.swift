// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import DLS
import PermissionsServiceInterface
import SwiftUI

// MARK: - OnboardingView

#if DEBUG

func createMockPermissionService() -> MockPermissionsService {
  let service = MockPermissionsService()
  service.onRequestAccessibilityPermission = {
    Task {
      try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate a delay
      await service.set(permission: .accessibility, granted: true)
    }
  }
  service.onRequestXcodeExtensionPermission = {
    Task {
      try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate a delay
      await service.set(permission: .xcodeExtension, granted: true)
    }
  }
  return service
}

struct AIProvidersView: View {

  var body: some View {
    VStack {
      Text("Providers View")
    }
  }
}

extension OnboardingView {
  init(
    createAIAIProvidersView: @Sendable @escaping () -> AnyView)
  {
    self.init(
      viewModel: OnboardingViewModel(),
      createAIAIProvidersView: createAIAIProvidersView)
  }
}

#Preview("OnboardingView") {
  withDependencies {
    $0.permissionsService = createMockPermissionService()
  } operation: {
    OnboardingView(createAIAIProvidersView: {
      AnyView(AIProvidersView())
    })
  }
}

#endif
