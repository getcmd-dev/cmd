// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import LoggingServiceInterface
import SwiftUI

public struct PlainLink: View {
  public init(_ title: some StringProtocol, destination: URL?) {
    label = { Text(title) }
    if destination == nil {
      defaultLogger.error("The URL provided for the PlainLink is nil. title: \(title)")
    }
    self.destination = destination
  }

  @ViewBuilder public let label: () -> Text

  public let destination: URL?

  public var body: some View {
    if let destination {
      Link(destination: destination, label: label)
        .underline()
        .buttonStyle(PlainButtonStyle())
        .help(destination.absoluteString)
        .onHover { isHovering in
          if isHovering {
            NSCursor.pointingHand.push()
          } else {
            NSCursor.pop()
          }
        }
    } else {
      EmptyView()
    }
  }

}
