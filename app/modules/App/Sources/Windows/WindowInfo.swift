// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import Foundation

typealias WindowInfo = [CFString: AnyObject]

extension WindowInfo {
  var windowNumber: CGWindowID? {
    self[kCGWindowNumber] as? CGWindowID
  }

  var isOnScreen: Bool {
    self[kCGWindowIsOnscreen] as? Bool ?? false
  }

  static func window(withNumber windowNumber: CGWindowID) -> WindowInfo? {
    (CGWindowListCopyWindowInfo(.optionIncludingWindow, windowNumber) as? [WindowInfo])?.first
  }

  /// Finds windows matching the specified process ID and frame
  /// - Parameters:
  ///   - pid: The process ID to match
  ///   - cgFrame: The frame to match
  /// - Returns: An array of matching window information
  static func findWindowsMatching(pid: pid_t?, cgFrame: CGRect?) -> [WindowInfo] {
    guard let processID = pid else { return [] }

    guard
      let targetFrame = cgFrame,
      let allWindows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [WindowInfo]
    else {
      return []
    }
    return allWindows.compactMap { windowInfo in
      if windowInfo[kCGWindowOwnerPID] as? Int32 != processID {
        return nil
      }

      var windowBounds = CGRect.zero
      guard
        let boundsDictionary = windowInfo[kCGWindowBounds],
        CGRectMakeWithDictionaryRepresentation(
          boundsDictionary as! CFDictionary,
          &windowBounds)
      else {
        return nil
      }
      return windowBounds == targetFrame ? windowInfo : nil
    }
  }
}
