// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import FileDiffFoundation
import Foundation
import SwiftTesting
import Testing
@testable import CodeCompletionService

// MARK: - RecentEditsTrackingTests

@Suite("Recent Edits Tracking Tests")
struct RecentEditsTrackingTests {

  @Test("Tracks single file edit")
  func tracksSingleFileEdit() async throws {
    // given
    let root = URL(fileURLWithPath: "/workspace")
    let tracker = RecentEditsTracker(root: root)
    let file = URL(fileURLWithPath: "/workspace/file.swift")

    // when
    await tracker.trackEdit(file: file, content: nil)
    await tracker.trackEdit(file: file, content: "let x = 1")

    // then
    let history = await tracker.getEditHistory()
    #expect(history.count == 2)
    #expect(history.last?.url == file)
    #expect(history.last?.content == "let x = 1")
    let diff = await tracker.getDiff()
    #expect(diff.trimmingCharacters(in: .whitespacesAndNewlines) == """
      +++ b/workspace/file.swift
      @@ -0,0 +1 @@
      +let x = 1
      """.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  @Test("open file has no diff")
  func openFileHasNoDiff() async throws {
    // given
    let root = URL(fileURLWithPath: "/workspace")
    let tracker = RecentEditsTracker(root: root)
    let file = URL(fileURLWithPath: "/workspace/file.swift")

    // when
    await tracker.trackEdit(file: file, content: "let x = 1")

    // then
    let diff = await tracker.getDiff()
    #expect(diff.trimmingCharacters(in: .whitespacesAndNewlines) == "")
  }

  @Test("Tracks multiple edits to same file")
  func tracksMultipleEditsToSameFile() async throws {
    // given
    let root = URL(fileURLWithPath: "/workspace")
    let tracker = RecentEditsTracker(root: root)
    let file = URL(fileURLWithPath: "/workspace/file.swift")

    // when
    await tracker.trackEdit(file: file, content: "let x = 1")
    await tracker.trackEdit(file: file, content: "let x = 1\nlet y = 2")
    await tracker.trackEdit(file: file, content: "let x = 1\nlet y = 2\nlet z = 3")

    // then
    let history = await tracker.getEditHistory()
    #expect(history.count == 3)
    #expect(history.last?.content == "let x = 1\nlet y = 2\nlet z = 3")
  }

  @Test("Tracks file moved")
  func tracksFileMoved() async throws {
    // given
    let root = URL(fileURLWithPath: "/workspace")
    let tracker = RecentEditsTracker(root: root)
    let file1 = URL(fileURLWithPath: "/workspace/file1.swift")
    let file2 = URL(fileURLWithPath: "/workspace/file2.swift")

    // when
    await tracker.trackEdit(file: file1, content: """
      let x = 1
      let y = 2
      let z = 3
      """)
    await tracker.trackEdit(file: file1, content: nil)
    await tracker.trackEdit(file: file2, content: nil)
    await tracker.trackEdit(file: file2, content: """
      let x = 1
      let y = 2
      let z = 3
      """)
    await tracker.trackEdit(file: file2, content: """
      let x = 1
      let y = 2
      let z = 4
      """)

    // then
    let diff = await tracker.getDiff()
    #expect(diff.trimmingCharacters(in: .whitespacesAndNewlines) == """
      --- a/workspace/file1.swift
      +++ b/workspace/file2.swift
      @@ -1,3 +1,3 @@
       let x = 1
       let y = 2
      -let z = 3
      +let z = 4
      """.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  @Test("Handles nil content for file deletion")
  func handlesNilContentForDeletion() async throws {
    // given
    let root = URL(fileURLWithPath: "/workspace")
    let tracker = RecentEditsTracker(root: root)
    let file = URL(fileURLWithPath: "/workspace/file.swift")

    // when
    await tracker.trackEdit(file: file, content: "let x = 1")
    await tracker.trackEdit(file: file, content: nil) // File deleted

    // then
    let history = await tracker.getEditHistory()
    #expect(history.count == 2)
    #expect(history.last?.content == nil)
  }

  @Test("Batch processing works")
  func batchProcessingWorks() async throws {
    // given
    let root = URL(fileURLWithPath: "/workspace")
    let tracker = RecentEditsTracker(root: root)
    let file1 = URL(fileURLWithPath: "/workspace/file1.swift")
    let file2 = URL(fileURLWithPath: "/workspace/file2.swift")

    // when
    await tracker.process(updates: [
      (url: file1, content: "let x = 1"),
      (url: file2, content: "let y = 2"),
    ])

    // then
    let history = await tracker.getEditHistory()
    #expect(history.count == 2)
  }

  @Test("Stays within diff budget")
  func staysWithinDiffBudget() async throws {
    // given
    let root = URL(fileURLWithPath: "/workspace")
    let tracker = RecentEditsTracker(diffBudget: 50, root: root)
    let file = URL(fileURLWithPath: "/workspace/file.swift")

    // when - add many lines to exceed budget
    var content = "// Start"
    await tracker.trackEdit(file: file, content: content)

    for i in 1...100 {
      content += "\nlet var\(i) = \(i)"
      await tracker.trackEdit(file: file, content: content)
    }

    // then - should have pruned old edits
    let history = await tracker.getEditHistory()
    #expect(history.count < 101, "Should have pruned some edits")
    #expect(history.count > 0, "Should retain some edits")
  }

  @Test("Handles multi-file edits efficiently")
  func handlesMultiFileEdits() async throws {
    // given
    let root = URL(fileURLWithPath: "/workspace")
    let tracker = RecentEditsTracker(root: root)
    let file1 = URL(fileURLWithPath: "/workspace/file1.swift")
    let file2 = URL(fileURLWithPath: "/workspace/file2.swift")

    // when
    await tracker.trackEdit(file: file1, content: "let x = 1")
    await tracker.trackEdit(file: file2, content: "let y = 2")
    await tracker.trackEdit(file: file1, content: "let x = 10")

    // then
    let history = await tracker.getEditHistory()
    #expect(history.count == 3)

    // Check order (chronological, most recent last)
    #expect(history[0].url == file1)
    #expect(history[1].url == file2)
    #expect(history[2].url == file1)
  }

  @Test("Handles empty content")
  func handlesEmptyContent() async throws {
    // given
    let root = URL(fileURLWithPath: "/workspace")
    let tracker = RecentEditsTracker(root: root)
    let file = URL(fileURLWithPath: "/workspace/file.swift")

    // when
    await tracker.trackEdit(file: file, content: "")

    // then
    let history = await tracker.getEditHistory()
    #expect(history.count == 1)
    #expect(history.first?.content == "")
  }

  @Test("Tracks file creation and deletion cycle")
  func tracksFileCreationAndDeletionCycle() async throws {
    // given
    let root = URL(fileURLWithPath: "/workspace")
    let tracker = RecentEditsTracker(root: root)
    let file = URL(fileURLWithPath: "/workspace/temp.swift")

    // when
    await tracker.trackEdit(file: file, content: "let temp = 1") // Create
    await tracker.trackEdit(file: file, content: "let temp = 2") // Edit
    await tracker.trackEdit(file: file, content: nil) // Delete
    await tracker.trackEdit(file: file, content: "let temp = 3") // Recreate

    // then
    let history = await tracker.getEditHistory()
    #expect(history.count == 4)
    #expect(history[2].content == nil)
    #expect(history[3].content == "let temp = 3")
  }
}

extension RecentEditsTracker {
  func trackEdit(file: URL, content: String?) {
    process(updates: [(url: file, content: content)])
  }

  func getEditHistory() -> [FileVersion] {
    editsHistory
  }

  func getDiff() -> String {
    diff
  }
}
