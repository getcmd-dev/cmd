// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import ScreenCaptureKit

enum XcodeScreenshoter {
  static func screenshot(windowId: CGWindowID, frame: CGRect) async throws -> CGImage? {
    let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    guard let window = availableContent.windows.first(where: { $0.windowID == windowId }) else {
      return nil
    }

    let filter = SCContentFilter(desktopIndependentWindow: window)

    // 3. Capture the image using the filter and default configuration
    let configuration = SCStreamConfiguration()
    configuration.capturesAudio = false
    configuration.captureMicrophone = false
    configuration.sourceRect = frame
    configuration.width = Int(frame.width) * 2 // * 2 for retina display
    configuration.height = Int(frame.height) * 2
    configuration.showsCursor = false
    configuration.captureResolution = .best

    return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
  }
}
