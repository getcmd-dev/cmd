// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

//
//  RecentsEditsTracker2.swift
//  CodeCompletionService
//
//  Created by Guigui on 11/5/25.
//
import AppFoundation
import FileDiffFoundation
import Foundation
import LoggingServiceInterface

// MARK: - RecentEditsTracker

// NOTE: We manually track edits rather than using a git repository for the entire history
// because when a file is opened mid-stream, we need to set its baseline to the current
// content (not empty/nil), so we don't incur a diff of the full file content.
// This allows us to only track changes that happen after the file was opened.

// TODO: check behavior between open and created

actor RecentEditsTracker: Sendable {
  init(diffBudget: Int = 100, root: URL) {
    self.diffBudget = diffBudget
    self.root = root

    // Create persistent tmp directories for diff computation
    let tmpBase = FileManager.default.temporaryDirectory
    let uuid = UUID().uuidString
    oldContentDir = tmpBase.appendingPathComponent("recent-edits-old-\(uuid)", isDirectory: true)
    newContentDir = tmpBase.appendingPathComponent("recent-edits-new-\(uuid)", isDirectory: true)

    try? FileManager.default.createDirectory(at: oldContentDir, withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(at: newContentDir, withIntermediateDirectories: true)
  }

  deinit {
    // Clean up tmp directories
    try? FileManager.default.removeItem(at: oldContentDir)
    try? FileManager.default.removeItem(at: newContentDir)
  }

  /// The overall edit history (ordered by file, most recent is last)
  private(set) var editsHistory = [FileVersion]()
  private(set) var diff = ""

  func process(updates: [(url: URL, content: String?)]) {
    for update in updates {
      var versions = filesEditsHistory[update.url, default: []]
      versions.append(.init(url: update.url, content: update.content))
      filesEditsHistory[update.url] = versions

      editsHistory.append(.init(url: update.url, content: update.content))

      // Write to new content directory
      writeToTmpDir(newContentDir, file: update.url, content: update.content)
    }

    var startIndex = 0
    while true {
      if startIndex >= editsHistory.count {
        break
      }

      // Update old content directory to reflect state at startIndex
      updateOldContentDir(from: startIndex)

      do {
        let diff = try computeDiff()
        if size(of: diff) > diffBudget {
          startIndex += 1
        } else {
          self.diff = diff
          break
        }
      } catch {
        defaultLogger.error("Failed to compute diff for recent edits tracker", error)
        break
      }
    }
    discardsEdits(upTo: startIndex)
  }

  private let root: URL
  private let diffBudget: Int
  /// The edit history of each file (ordered by file, most recent is last)
  private var filesEditsHistory = [URL: [FileVersion]]()
  /// Persistent tmp directories for diff computation
  private let oldContentDir: URL
  private let newContentDir: URL

  private func updateOldContentDir(from idx: Int) {
    // Clear old content directory
    clearTmpDir(oldContentDir)

    // Build the state before edits starting at idx
    var beforeStateIdx = [URL: Int]()
    for edit in editsHistory[idx...] {
      beforeStateIdx[edit.url] = beforeStateIdx[edit.url, default: 0] + 1
    }

    // Write old state to tmp directory
    for (url, count) in beforeStateIdx {
      if let fileHistory = filesEditsHistory[url] {
        let historyIndex = fileHistory.count - count - 1
        if historyIndex >= 0 {
          let oldContent = fileHistory[historyIndex].content
          writeToTmpDir(oldContentDir, file: url, content: oldContent)
        }
        // If historyIndex < 0, file was created in this range, so no old content
      }
    }
  }

  private func computeDiff() throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = [
      "diff",
      "--no-index",
      "--no-color",
      oldContentDir.path,
      newContentDir.path,
    ]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else {
      throw AppError("Failed to decode git diff output")
    }

    // Git diff --no-index returns exit code 1 when there are differences (which is expected)
    // Only throw if exit code is not 0 or 1
    if process.terminationStatus > 1 {
      throw AppError("Git diff failed with exit code \(process.terminationStatus)")
    }

    // Remove the first 4 lines (git headers) if present
    let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
    guard lines.count > 4 else { return output }

    return lines.dropFirst(4).joined(separator: "\n")
  }

  private func size(of diff: String) -> Int {
    diff.split(separator: "\n").count
  }

  private func discardsEdits(upTo idx: Int) {
    var editsCount = [URL: Int]()
    for edit in editsHistory[..<idx] {
      editsCount[edit.url] = editsCount[edit.url, default: 0] + 1
    }
    for (url, count) in editsCount {
      if var fileHistory = filesEditsHistory[url] {
        if fileHistory.count >= count {
          fileHistory.removeFirst(count)
          filesEditsHistory[url] = fileHistory
        }
      }
    }
    editsHistory.removeFirst(idx)
  }

  private func writeToTmpDir(_ dir: URL, file: URL, content: String?) {
    let relativePath = file.pathRelative(to: root)
    let tmpFile = dir.appendingPathComponent(relativePath)

    // Create parent directories if needed
    let parentDir = tmpFile.deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

    if let content {
      // Write content
      try? content.write(to: tmpFile, atomically: true, encoding: .utf8)
    } else {
      // nil content could mean file was deleted OR created
      // If file exists in tmp dir, it was deleted; otherwise it was created
      let fileExists = FileManager.default.fileExists(atPath: tmpFile.path)
      if fileExists {
        // File was deleted - remove from tmp dir
        try? FileManager.default.removeItem(at: tmpFile)
      }
      // If file doesn't exist, it was created - do nothing (leave it absent from tmp dir)
    }
  }

  private func clearTmpDir(_ dir: URL) {
    guard let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else {
      return
    }

    for case let fileURL as URL in enumerator {
      try? FileManager.default.removeItem(at: fileURL)
    }
  }
}

// MARK: - FileVersion

struct FileVersion: Sendable {
  let url: URL
  let content: String?
}
