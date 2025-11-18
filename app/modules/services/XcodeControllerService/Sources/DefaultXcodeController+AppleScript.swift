// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation
import LoggingServiceInterface

// MARK: DefaultXcodeController + AppleScript
extension DefaultXcodeController {

  @MainActor
  static func run(appleScript: String) throws {
    guard let script = NSAppleScript(source: appleScript) else {
      assertionFailure("Could not create NSAppleScript object.")
      throw AppError(message: "Could not create NSAppleScript object.")
    }

    var errorDict: NSDictionary?
    script.executeAndReturnError(&errorDict)

    if let error = errorDict {
      defaultLogger.error("AppleScript Error: \(error)")
      throw AppError(message: "AppleScript Error: \(error)")
    }
  }

  @MainActor
  static func activateXcodeWithAppleScript() throws {
    try run(appleScript: """
        tell application "Xcode" to activate
        delay 0.1
      """)
  }

  /// Modify the content of the file using Apple Script. This might lead to a non ideal UX with the code moving around in the editor but is a good fallback.
  @MainActor
  static func openFileWithAppleScript(at path: URL) throws {
    try run(appleScript: """
      tell application "Xcode"
          set theFilePath to "\(path.path)"
          open theFilePath
          repeat 10 times
              try
                  set doc to first source document whose path is theFilePath
                  exit repeat
              on error
                  delay 0.1
              end try
          end repeat
      end tell
      delay 0.1
      """)
  }

}
