// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import DLS
import Onboarding
import RoutingFoundation
import SwiftUI

final class SetupWindow: NSWindow {

  init(onComplete: @escaping () -> Void) {
    // Use a temporary size that will be adjusted once content is loaded
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
      styleMask: [.closable, .miniaturizable, .resizable, .titled],
      backing: .buffered,
      defer: false)

    let routesRegistry = RoutesRegistry()
    routesRegistry.registerRoutes()
    let router = Router(registry: routesRegistry)

    let root = RoutableNavigationStack(
      router: router,
      rootView: OnboardingFeatureBuilder.build(.init(
        bringWindowToFront: { [weak self] in
          NSApplication.shared.activate()
          self?.makeKeyAndOrderFront(nil)
          self?.orderFrontRegardless()
        },
        onDone: {
          onComplete()
        })),
      navBarBuilder: { dismiss in
        HStack {
          BackButton { dismiss() }
            .padding()
          Spacer()
        }
      },
      defaultBackgroundColor: { $0.primaryBackground })
      .frame(maxWidth: .infinity, maxHeight: .infinity)

    let hostingView = NSHostingView(rootView: root)

    hostingView.translatesAutoresizingMaskIntoConstraints = false
    contentView = hostingView

    if let contentView {
      NSLayoutConstraint.activate([
        hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
        hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
        hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      ])
    }

    // Size window to fit content
    setContentSize(hostingView.fittingSize)

    // Center window on screen
    center()
  }
}
