// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import Foundation

extension FileDiff {
  /// Rebase a suggested change to match the current content of a file.
  ///
  /// - Parameters:
  ///   - baselineContent: The initial content of the file before any change was made for the context of interest.
  ///   - currentContent: The current content of the file.
  ///   - targetContent: The change that was proposed from the baseline.
  /// - Returns: The rebased change, which might contain conflict markers.
  public static func rebaseChange(
    baselineContent: String,
    currentContent: String,
    targetContent: String)
    throws -> String
  {
    let tmpDir = try shell("mktemp -d")

    let tmpFileV0Path = try shell("mktemp")
    let tmpFileV1Path = try shell("mktemp")
    let tmpFileV2Path = try shell("mktemp")
    let filePath = "\(tmpDir)/file"

    try FileManager.default.write(
      data: baselineContent.formattedToApplyGitDiff.utf8Data,
      to: URL(filePath: tmpFileV0Path))
    try FileManager.default.write(
      data: currentContent.formattedToApplyGitDiff.utf8Data,
      to: URL(filePath: tmpFileV1Path))
    try FileManager.default.write(
      data: targetContent.formattedToApplyGitDiff.utf8Data,
      to: URL(filePath: tmpFileV2Path))

    defer {
      try? FileManager.default.removeItem(atPath: tmpFileV0Path)
      try? FileManager.default.removeItem(atPath: tmpFileV1Path)
      try? FileManager.default.removeItem(atPath: tmpFileV2Path)
      try? FileManager.default.removeItem(atPath: filePath)
      try? FileManager.default.removeItem(atPath: tmpDir)
    }

    let command = """
      cd \(tmpDir) && git init && git add . && git commit -m 'Initial commit' --allow-empty && \
      cp \(tmpFileV0Path) file && git add . && git commit -m 'baseline' --allow-empty && \
      git checkout -b current && git checkout -b suggestion && \
      cp \(tmpFileV2Path) file && git add . && git commit -m 'target' --allow-empty && \
      git checkout current && cp \(tmpFileV1Path) file && git add . && git commit -m 'current' --allow-empty && \
      git merge suggestion --no-edit
      """

    _ = try shell(command)
    let mergedContentData = try Data(contentsOf: URL(filePath: "\(tmpDir)/file"))
    guard let mergedContent = String(data: mergedContentData, encoding: .utf8) else {
      throw AppError(message: "Failed to read the merged content.")
    }

    return mergedContent.unformattedFromApplyGitDiff
  }
}
