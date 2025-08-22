// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation
import LoggingServiceInterface

extension FileDiff {

  /// Computes the diff between two strings using git.
  public static func getGitDiff(oldContent: String, newContent: String) throws -> String {
    let uuid = UUID().uuidString
    let tmpFileV0Path = "/tmp/file-0-\(uuid).txt"
    let tmpFileV1Path = "/tmp/file-1-\(uuid).txt"

    FileManager.default.createFile(
      atPath: tmpFileV0Path,
      contents: oldContent.formattedToApplyGitDiff.utf8Data,
      attributes: nil)
    FileManager.default.createFile(
      atPath: tmpFileV1Path,
      contents: newContent.formattedToApplyGitDiff.utf8Data,
      attributes: nil)

    defer {
      try? FileManager.default.removeItem(atPath: tmpFileV0Path)
      try? FileManager.default.removeItem(atPath: tmpFileV1Path)
    }

    let diff = try shell("git diff --no-index --no-color \(tmpFileV0Path) \(tmpFileV1Path)")
      .split(separator: "\n", omittingEmptySubsequences: false)
      // First 4 lines are formatted like:
      //
      // diff --git a/tmp/oldContent.txt b/tmp/newContent.txt
      // index 41df449..84d2978 100644
      // --- a/tmp/oldContent.txt
      // +++ b/tmp/newContent.txt
      .dropFirst(4)
      .joined(separator: "\n")

    return diff.formatAppliedGitDiff
  }

  static func shell(_ command: String) throws -> String {
    let task = Process()
    let stdout = Pipe()
    let stderr = Pipe()

    task.standardOutput = stdout
    task.standardError = stderr
    task.arguments = ["-c", command]
    task.launchPath = "/bin/zsh"
    task.standardInput = nil
    task.launch()

    let data = stdout.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }
}

extension String {

  // `git diff` doesn't format added/removed empty lines.
  // To make sure that such lines are formatted as either `{++}\n` or `[--]\n`, we add a fixed token that is later removed.
  //
  // Regex: match all new lines whose next character is a new line or the end of file.
  var formattedToApplyGitDiff: String {
    replacingOccurrences(of: "\n\(Self.emptyLineToken)", with: "\n\(Self.emptyLineToken)\(Self.emptyLineToken)")
      .replacingOccurrences(
        of: "(\n)(?=\n|$)",
        with: "$1\(Self.emptyLineToken)",
        options: .regularExpression)
  }

  var unformattedFromApplyGitDiff: String {
    replacingOccurrences(
      of: "(\n)\(Self.emptyLineToken)(?=\n|$)",
      with: "$1",
      options: .regularExpression)
      .replacingOccurrences(
        of: "\n\(Self.emptyLineToken)\(Self.emptyLineToken)(?=\n|$)",
        with: "\n\(Self.emptyLineToken)",
        options: .regularExpression)
  }

  var formatAppliedGitDiff: String {
    replacingOccurrences(of: "\n \(Self.emptyLineToken)", with: "\n ")
      .replacingOccurrences(of: "\n+\(Self.emptyLineToken)", with: "\n+")
      .replacingOccurrences(of: "\n-\(Self.emptyLineToken)", with: "\n-")
  }

  private static let emptyLineToken = "<l>"

}
