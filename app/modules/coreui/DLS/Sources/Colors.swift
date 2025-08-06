// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

extension NSColor {
  var inverted: NSColor {
    var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
    getRed(&r, green: &g, blue: &b, alpha: &a)
    return NSColor(red: 1 - r, green: 1 - g, blue: 1 - b, alpha: a)
  }

  /// For an NSColor in the RBG color space, returns the hex string representation.
  var hex: String {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0

    getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    // Convert to 255-based and format as hex
    let rgb =
      Int(red * 255) << 16 |
      Int(green * 255) << 8 |
      Int(blue * 255) << 0
    return String(format: "#%06x", rgb)
  }

  func mixed(with color2: NSColor, proportion: CGFloat) -> NSColor {
    var p = proportion
    if p > 1 {
      p = 1
    } else if p < 0 {
      p = 0
    }

    var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
    getRed(&r, green: &g, blue: &b, alpha: &a)

    var r2: CGFloat = 0.0, g2: CGFloat = 0.0, b2: CGFloat = 0.0, a2: CGFloat = 0.0
    color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

    return NSColor(
      red: r + (r2 - r) * p,
      green: g + (g2 - g) * p,
      blue: b + (b2 - b) * p,
      alpha: a + (a2 - a) * p)
  }

}

extension Color {
  var inverted: Color {
    Color(nsColor: nsColor.inverted)
  }

  func mixed(with color2: Color, proportion: CGFloat) -> Color {
    Color(nsColor: nsColor.mixed(with: color2.nsColor, proportion: proportion))
  }
}

extension Color {
  public var nsColor: NSColor { NSColor(self).usingColorSpace(.deviceRGB)! }
  public var cgColor: CGColor { nsColor.cgColor }
}

extension ColorScheme {
  public var primaryBackground: Color {
    xcodeSidebarBackground
  }

  public var primaryForeground: Color {
    self == .dark ? .white : .black
  }

  public var secondaryForeground: Color {
    self == .dark ? Color(white: 0.8) : Color(white: 0.2)
  }

  // TODO: this depends on the theme used in Xcode.
  // The current color schema can be read with `defaults read ~/Library/Preferences/com.apple.dt.Xcode | grep XCFontAndColorCurrent`
  // also contains indentation info, path to the default app (eg file:///Applications/Xcode-16.2.0.app/),
  // key binding
  public var xcodeEditorBackground: Color {
    self == .dark ? Color(red: 41.0 / 255, green: 42.0 / 255, blue: 48.0 / 255) : .white
  }

  public var xcodeInputBackground: Color {
    self == .dark ? Color(red: 28.0 / 255, green: 28.0 / 255, blue: 29.0 / 255) : .white
  }

  public var xcodeSidebarBackground: Color {
    self == .dark
      ? Color(red: 42 / 255, green: 42 / 255, blue: 40 / 255)
      : Color(
        red: 237 / 255,
        green: 236 / 255,
        blue: 235 / 255)
  }

  public var addedLineDiffBackground: Color {
    self == .dark
      ? Color(red: 18 / 255, green: 58 / 255, blue: 27 / 255)
      : Color(red: 230 / 255, green: 255 / 255, blue: 237 / 255)
  }

  public var removedLineDiffBackground: Color {
    self == .dark
      ? Color(red: 69 / 255, green: 12 / 255, blue: 15 / 255)
      : Color(red: 255 / 255, green: 238 / 255, blue: 240 / 255)
  }

  public var addedLineDiffText: Color {
    self == .dark
      ? Color(red: 76 / 255, green: 161 / 255, blue: 93 / 255)
      : Color(red: 24 / 255, green: 107 / 255, blue: 47 / 255)
  }

  public var removedLineDiffText: Color {
    self == .dark
      ? Color(red: 218 / 255, green: 75 / 255, blue: 83 / 255)
      : Color(red: 179 / 255, green: 29 / 255, blue: 40 / 255)
  }

  public var redError: Color {
    .red
  }

  public var greenSuccess: Color {
    .green
  }

  public var toolUseForeground: Color {
    .secondary
  }

  public var tertiarySystemBackground: Color {
    let background = systemBackground
    if self == .dark {
      return background.mixed(with: background.inverted, proportion: 0.1)
    } else {
      return background.mixed(with: background.inverted, proportion: 0.1)
    }
  }

  public var secondarySystemBackground: Color {
    let background = systemBackground
    if self == .dark {
      return background.mixed(with: background.inverted, proportion: 0.008)
    } else {
      return background.mixed(with: background.inverted, proportion: 0.05)
    }
  }

  public var systemBackground: Color {
    self == .dark ? Color(white: 0.19608) : Color(white: 0.92549)
  }

  public var textAreaBorderColor: Color {
    self == .dark ? .gray.opacity(0.5) : .gray.opacity(0.3)
  }

  public var xcodeWarningColor: Color {
    self == .dark
      ? Color(red: 255 / 255, green: 198 / 255, blue: 0 / 255)
      : Color(red: 202 / 255, green: 9 / 255, blue: 0 / 255)
  }

  /// 236,35,56 || 202,9,0
  public var xcodeErrorColor: Color {
    self == .dark
      ? Color(red: 236 / 255, green: 35 / 255, blue: 56 / 255)
      : Color(red: 202 / 255, green: 9 / 255, blue: 0 / 255)
  }

  /// 92,200,35 || 73,197,13
  public var xcodeSuccessColor: Color {
    self == .dark
      ? Color(red: 92 / 255, green: 200 / 255, blue: 35 / 255)
      : Color(red: 73 / 255, green: 197 / 255, blue: 13 / 255)
  }
}
