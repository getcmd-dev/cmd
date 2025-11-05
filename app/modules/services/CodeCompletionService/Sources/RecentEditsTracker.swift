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

// TODO: check behavior between open and created

actor RecentEditsTracker: Sendable {
  init(diffBudget: Int = 100, root: URL) {
    self.diffBudget = diffBudget
    self.root = root
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
    }

    var startIndex = 0
    while true {
      if startIndex >= editsHistory.count {
        break
      }
      do {
        let diff = try computeDiff(from: 0)
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

  private func computeDiff(from idx: Int) throws -> String {
    var newContent = [URL: String?]()
    var beforeStateIdx = [URL: Int]()

    for edit in editsHistory[idx...] {
      newContent[edit.url] = edit.content
      beforeStateIdx[edit.url] = beforeStateIdx[edit.url, default: 0] + 1
    }
    var oldContent = [URL: String?]()
    for (url, count) in beforeStateIdx {
      if let fileHistory = filesEditsHistory[url] {
        if fileHistory.count > count {
          oldContent[url] = fileHistory[fileHistory.count - count - 1].content
        } else if let content = fileHistory.first?.content {
          oldContent[url] = content
        } else {
          assertionFailure("File history too short for \(url.path)")
          oldContent[url] = nil
        }
      } else {
        assertionFailure("File history missing for \(url.path)")
        oldContent[url] = nil
      }
    }

    return try FileDiff.getGitDiff(
      oldContent: Dictionary(uniqueKeysWithValues: oldContent.compactMapValues(\.self).map { k, v in
        (k.pathRelative(to: root), v)
      }),
      newContent: Dictionary(uniqueKeysWithValues: newContent.compactMapValues(\.self).map { k, v in
        (k.pathRelative(to: root), v)
      }))
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
}

// MARK: - FileVersion

struct FileVersion: Sendable {
  let url: URL
  let content: String?
}
