// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import Foundation

/// Controller for extracting font information from Xcode themes
public actor XcodeThemeController {
  public init(getXcodePath: @escaping @Sendable () async throws -> String) {
    self.getXcodePath = getXcodePath
  }

  /// Get the current Xcode theme font
  /// - Returns: The font from Xcode's active theme, or a default if unavailable
  public func getCurrentThemeFont() async -> XcodeTheme.ThemeFont {
    // Return cached value if available
    if let cached = cachedFont {
      return cached
    }

    // Try to get the current theme name from Xcode preferences
    let themeName = getCurrentXcodeThemeName()

    // Locate the theme file
    if let themeURL = await locateXcodeTheme(named: themeName) {
      do {
        let font = try parser.parse(fileURL: themeURL).plainTextFont

        cachedFont = font
        return font
      } catch {
        // Fall through to default
      }
    }

    // Default fallback
    let defaultFont = XcodeTheme.ThemeFont(name: "SFMono-Medium", size: 12.0)
    cachedFont = defaultFont
    return defaultFont
  }

  /// Invalidate the cached font (call when theme changes)
  public func invalidateCache() {
    cachedFont = nil
  }

  private let getXcodePath: @Sendable () async throws -> String

  private let parser = XcodeThemeParser()
  private var cachedFont: XcodeTheme.ThemeFont?

  // MARK: - Private Helpers

  /// Get the current Xcode theme name from preferences
  private func getCurrentXcodeThemeName() -> String {
    // Try to read Xcode's preferences
    // The theme name is stored in ~/Library/Preferences/com.apple.dt.Xcode.plist
    let prefsURL = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Preferences/com.apple.dt.Xcode.plist")

    if let prefs = NSDictionary(contentsOf: prefsURL) as? [String: Any] {
      // Check for both light and dark theme (we'll use the first one we find)
      if let theme = prefs["XCFontAndColorCurrentTheme"] as? String {
        return theme
      }
      if let theme = prefs["XCFontAndColorCurrentDarkTheme"] as? String {
        return theme
      }
    }

    // Default to a common theme
    return "Default (Dark).xccolortheme"
  }

  /// Locate an Xcode theme file by name
  /// - Parameter name: The theme name (e.g., "Default (Dark).xccolortheme")
  /// - Returns: URL to the theme file, or nil if not found
  private func locateXcodeTheme(named name: String) async -> URL? {
    let fileManager = FileManager.default

    // Ensure the name has the correct extension
    let themeName = name.hasSuffix(".xccolortheme") ? name : "\(name).xccolortheme"

    // Search locations:
    // 1. User's custom themes
    if
      let userThemesURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first?
        .appendingPathComponent("Developer/Xcode/UserData/FontAndColorThemes")
        .appendingPathComponent(themeName),
      fileManager.fileExists(atPath: userThemesURL.path)
    {
      return userThemesURL
    }

    // 2. Xcode's built-in themes
    if let xcodeAppPath = try? await getXcodePath() {
      let builtInThemesPath = "\(xcodeAppPath)/Contents/SharedFrameworks/DVTUserInterfaceKit.framework/Versions/A/Resources/FontAndColorThemes/\(themeName)"
      if fileManager.fileExists(atPath: builtInThemesPath) {
        return URL(fileURLWithPath: builtInThemesPath)
      }
    }

    // 3. Try common Xcode beta locations
    if let betaApps = try? fileManager.contentsOfDirectory(atPath: "/Applications") {
      for app in betaApps where app.hasPrefix("Xcode") && app.hasSuffix(".app") {
        let betaPath = "/Applications/\(app)/Contents/SharedFrameworks/DVTUserInterfaceKit.framework/Versions/A/Resources/FontAndColorThemes/\(themeName)"
        if fileManager.fileExists(atPath: betaPath) {
          return URL(fileURLWithPath: betaPath)
        }
      }
    }

    return nil
  }
}
