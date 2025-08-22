// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

public struct PlainLink: View {
  public init(_ title: some StringProtocol, destination: URL) {
    label = { Text(title) }
    self.destination = destination
  }

  @ViewBuilder public let label: () -> Text

  public let destination: URL

  public var body: some View {
    Link(destination: destination, label: label)
      .underline()
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
