// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import LoggingServiceInterface
import SwiftUI

public struct PlainLink: View {
  public init(
    _ title: some StringProtocol,
    destination: URL?)
  {
    self.init(title, action: {
      if let destination {
        NSWorkspace.shared.open(destination)
      }
    })
  }

  public init(
    _ title: some StringProtocol,
    action: @escaping () -> Void)
  {
    label = { Text(title) }
    self.action = action
  }

  @ViewBuilder public let label: () -> Text

  public let action: () -> Void

  public var body: some View {
    Button(action: action) {
      label()
        .underline()
    }
    .buttonStyle(PlainButtonStyle())
    .onHover { isHovering in
      if isHovering {
        NSCursor.pointingHand.push()
      } else {
        NSCursor.pop()
      }
    }
  }

}
