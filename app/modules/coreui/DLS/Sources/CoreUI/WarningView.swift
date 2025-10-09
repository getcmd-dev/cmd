// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - WarningView

public struct WarningView: View {
  public init(title: String, subtext: @escaping @autoclosure () -> Text) {
    self.title = title
    self.subtext = subtext
  }

  public init(title: String, subtext: some StringProtocol) {
    self.title = title
    self.subtext = { Text(subtext) }
  }

  @ViewBuilder public let subtext: () -> Text

  public var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundColor(.orange)
        .font(.system(size: 16))
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.subheadline)
          .fontWeight(.medium)
        subtext()
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .padding(12)
    .background(Color.orange.opacity(0.1))
    .cornerRadius(8)
  }

  let title: String

}
