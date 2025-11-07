// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Utility for determining LSP language identifiers from file URLs.
/// Based on the reference implementation in CopilotForXcode.
enum LanguageIdentifier {

  /// Determine the language ID from a file URL based on file extension.
  /// This matches the approach used in the reference CopilotForXcode implementation.
  /// Note: Extensions are matched case-sensitively (e.g., "C" for C++ header files)
  /// - Parameter fileURL: The file URL to determine the language ID for
  /// - Returns: The LSP language identifier string
  static func languageId(from fileURL: URL) -> String {
    let ext = fileURL.pathExtension
    switch ext {
    // Swift and Objective-C
    case "swift": return "swift"
    case "m", "mm": return "objective-c"
    // C/C++
    case "c": return "c"
    case "cpp", "cc", "cxx", "c++", "C": return "cpp"
    case "h": return "c" // Header could be C or C++, default to C
    case "hpp", "hh", "hxx", "h++": return "cpp"
    // Web technologies
    case "js", "mjs", "cjs": return "javascript"
    case "ts", "mts", "cts": return "typescript"
    case "jsx": return "javascriptreact"
    case "tsx": return "typescriptreact"
    case "html", "htm": return "html"
    case "css": return "css"
    case "scss", "sass": return "scss"
    case "less": return "less"
    // Other popular languages
    case "py", "pyw": return "python"
    case "java": return "java"
    case "kt", "kts": return "kotlin"
    case "rs": return "rust"
    case "go": return "go"
    case "rb": return "ruby"
    case "php": return "php"
    case "sh", "bash": return "shellscript"
    case "sql": return "sql"
    // Data formats
    case "json": return "json"
    case "xml", "plist": return "xml"
    case "yaml", "yml": return "yaml"
    case "toml": return "toml"
    // Documentation
    case "md", "markdown": return "markdown"
    case "txt": return "plaintext"
    default: return "plaintext"
    }
  }

}
