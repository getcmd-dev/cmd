// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import Down
import SwiftUI

// MARK: - MarkdownStyle

public class MarkdownStyle: DownStyle {

  public init(
    colorScheme: ColorScheme,
    foregroundColor: SwiftUI.Color? = nil)
  {
    super.init()

    baseFont = Font.systemFont(ofSize: 14, weight: .regular)
    baseFontColor = (foregroundColor ?? colorScheme.primaryForeground).nsColor

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.paragraphSpacingBefore = 0
    paragraphStyle.paragraphSpacing = 0
    paragraphStyle.lineSpacing = 3
    baseParagraphStyle = paragraphStyle

    h1Size = 18
    h2Size = 16
    h3Size = 15
    codeFont = .monospacedSystemFont(ofSize: 13, weight: .regular)
    codeColor = .controlAccentColor
    quoteColor = .secondaryLabelColor
  }

  public override var h1Attributes: DownStyle.Attributes {
    super.h1Attributes.merging([
      .font: baseFont.withSize(h1Size),
    ])
  }

  public override var h2Attributes: DownStyle.Attributes {
    super.h2Attributes.merging([
      .font: baseFont.withSize(h2Size),
    ])
  }

  public override var h3Attributes: DownStyle.Attributes {
    super.h3Attributes.merging([
      .font: baseFont.withSize(h3Size),
    ])
  }
}

extension ColorScheme {
  public var markDownStyle: MarkdownStyle {
    .init(colorScheme: self)
  }
}

extension DownStyle.Attributes {
  public func merging(_ other: DownStyle.Attributes) -> DownStyle.Attributes {
    merging(other, uniquingKeysWith: { $1 })
  }
}
