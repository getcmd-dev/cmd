// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import AppKit
import Dependencies
import Foundation
@_exported import HighlightSwift

// MARK: - HighlighterServiceProviding

public protocol HighlighterServiceProviding {
  var highlighter: Highlight { get }
}

extension HighlightColors {

  /// Provides theme-aware syntax highlighting colors based on system appearance.
  /// @MainActor ensures thread safety when accessing NSAppearance APIs.
  @MainActor
  public static var codeHighlight: HighlightColors {
    #if DEBUG
    if ProcessInfo.processInfo.isRunningInTestEnvironment {
      return .dark(.xcode)
    }
    #endif
    let isDarkMode = NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    if isDarkMode {
      return .dark(.xcode)
    } else {
      return .light(.xcode)
    }
  }
}
