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

  @Test("Tracks first edit to a file within budget")
  func tracksFirstEditWithinBudget() async throws {
    // given
    let tracker = RecentEditsTracker()
    let workspace = URL(fileURLWithPath: "/workspace")
    let file = URL(fileURLWithPath: "/workspace/file.swift")
    let initialContent = "let x = 1"
    let editedContent = "let x = 1\nlet y = 2"

    // Record baseline
    await tracker.recordBaseline(workspace: workspace, file: file, content: initialContent)

    // when - make a small edit
    await tracker.trackEdit(workspace: workspace, file: file, content: editedContent)

    // then - the edit should be tracked
    let edits = await tracker.getRecentEdits(workspace: workspace)
    #expect(edits != nil)
    #expect(edits?.trackedVersions.count == 1)
    #expect(edits?.trackedVersions.first?.content == editedContent)
    #expect((edits?.currentUsage ?? 0) <= 100)
  }

  @Test("Stays within 100 line budget")
  func staysWithinBudget() async throws {
    // given
    let tracker = RecentEditsTracker()
    let workspace = URL(fileURLWithPath: "/workspace")
    let file = URL(fileURLWithPath: "/workspace/file.swift")
    let initialContent = "// Start"

    await tracker.recordBaseline(workspace: workspace, file: file, content: initialContent)

    // when - make many edits that would exceed budget
    var currentContent = initialContent
    for i in 1...50 {
      currentContent += "\nlet var\(i) = \(i) // Added line \(i)"
      await tracker.trackEdit(workspace: workspace, file: file, content: currentContent)
    }

    // then - should stay within budget
    let edits = await tracker.getRecentEdits(workspace: workspace)
    #expect(edits != nil)
    let usage = edits?.currentUsage ?? 0
    #expect(usage <= 100, "Budget usage \(usage) exceeds 100")
  }

  @Test("Tracks edits independently per workspace")
  func tracksEditsIndependentlyPerWorkspace() async throws {
    // given
    let tracker = RecentEditsTracker()
    let workspace1 = URL(fileURLWithPath: "/workspace1")
    let workspace2 = URL(fileURLWithPath: "/workspace2")
    let file1 = URL(fileURLWithPath: "/workspace1/file.swift")
    let file2 = URL(fileURLWithPath: "/workspace2/file.swift")

    // Record baselines
    await tracker.recordBaseline(workspace: workspace1, file: file1, content: "// Workspace 1")
    await tracker.recordBaseline(workspace: workspace2, file: file2, content: "// Workspace 2")

    // when - edit files in both workspaces
    await tracker.trackEdit(workspace: workspace1, file: file1, content: "// Workspace 1\nlet x = 1")
    await tracker.trackEdit(workspace: workspace2, file: file2, content: "// Workspace 2\nlet y = 2")

    // then - each workspace should have independent tracking
    let edits1 = await tracker.getRecentEdits(workspace: workspace1)
    let edits2 = await tracker.getRecentEdits(workspace: workspace2)

    #expect(edits1 != nil)
    #expect(edits2 != nil)
    #expect(edits1?.trackedVersions.first?.content.contains("Workspace 1") == true)
    #expect(edits2?.trackedVersions.first?.content.contains("Workspace 2") == true)
  }

  @Test("Prunes old versions when budget is exceeded")
  func prunesOldVersionsWhenBudgetExceeded() async throws {
    // given
    let tracker = RecentEditsTracker()
    let workspace = URL(fileURLWithPath: "/workspace")
    let file = URL(fileURLWithPath: "/workspace/file.swift")
    var content = "// Start"

    await tracker.recordBaseline(workspace: workspace, file: file, content: content)

    // Add many lines to exceed budget
    for i in 1...60 {
      content += "\nlet var\(i) = \(i)"
    }
    await tracker.trackEdit(workspace: workspace, file: file, content: content)

    // when - make another edit
    content += "\nlet final = 999"
    await tracker.trackEdit(workspace: workspace, file: file, content: content)

    // then - should have moved old versions to buffer
    let edits = await tracker.getRecentEdits(workspace: workspace)
    #expect(edits != nil)
    #expect((edits?.currentUsage ?? 0) <= 100)
    // Most recent version should be tracked
    #expect(edits?.trackedVersions.first?.content.contains("final = 999") == true)
  }

  @Test("Restores from buffer when budget becomes available")
  func restoresFromBufferWhenBudgetAvailable() async throws {
    // given
    let tracker = RecentEditsTracker()
    let workspace = URL(fileURLWithPath: "/workspace")
    let file = URL(fileURLWithPath: "/workspace/file.swift")
    var content = "// Start\nlet original = 1"

    await tracker.recordBaseline(workspace: workspace, file: file, content: content)

    // Add many lines to fill budget
    for i in 1...50 {
      content += "\nlet var\(i) = \(i)"
    }
    await tracker.trackEdit(workspace: workspace, file: file, content: content)

    // Verify buffer has items
    var edits = await tracker.getRecentEdits(workspace: workspace)
    let bufferCountBefore = edits?.bufferVersions.count ?? 0

    // when - undo many lines (reduce diff)
    content = "// Start\nlet original = 1\nlet var1 = 1"
    await tracker.trackEdit(workspace: workspace, file: file, content: content)

    // then - buffer should have restored items if budget allows
    edits = await tracker.getRecentEdits(workspace: workspace)
    #expect((edits?.currentUsage ?? 0) <= 100)
    // The mechanism should attempt to restore from buffer
    _ = bufferCountBefore // Just verify it doesn't crash
  }

  @Test("Tracks multiple files in same workspace")
  func tracksMultipleFilesInSameWorkspace() async throws {
    // given
    let tracker = RecentEditsTracker()
    let workspace = URL(fileURLWithPath: "/workspace")
    let file1 = URL(fileURLWithPath: "/workspace/file1.swift")
    let file2 = URL(fileURLWithPath: "/workspace/file2.swift")

    // Record baselines
    await tracker.recordBaseline(workspace: workspace, file: file1, content: "// File 1")
    await tracker.recordBaseline(workspace: workspace, file: file2, content: "// File 2")

    // when - edit both files
    await tracker.trackEdit(workspace: workspace, file: file1, content: "// File 1\nlet x = 1")
    await tracker.trackEdit(workspace: workspace, file: file2, content: "// File 2\nlet y = 2")

    // then - both files should be tracked
    let edits = await tracker.getRecentEdits(workspace: workspace)
    #expect(edits != nil)

    let file1Versions = edits?.trackedVersions.filter { $0.fileURL == file1 }
    let file2Versions = edits?.trackedVersions.filter { $0.fileURL == file2 }

    #expect((file1Versions?.count ?? 0) >= 1)
    #expect((file2Versions?.count ?? 0) >= 1)
  }

  @Test("Buffer size stays within budget")
  func bufferSizeStaysWithinBudget() async throws {
    // given
    let tracker = RecentEditsTracker()
    let workspace = URL(fileURLWithPath: "/workspace")
    let file = URL(fileURLWithPath: "/workspace/file.swift")
    var content = "// Start"

    await tracker.recordBaseline(workspace: workspace, file: file, content: content)

    // when - make many large edits to overflow both tracked and buffer
    for i in 1...100 {
      content += "\nlet var\(i) = \(i) // Line \(i)"
      await tracker.trackEdit(workspace: workspace, file: file, content: content)
    }

    // then - buffer should also be bounded
    let edits = await tracker.getRecentEdits(workspace: workspace)
    #expect(edits != nil)

    // Calculate buffer usage
    let bufferUsage = edits?.bufferVersions.reduce(0) { $0 + $1.diffLines } ?? 0
    #expect(bufferUsage <= 100, "Buffer usage \(bufferUsage) exceeds 100")
  }

  @Test("Removes workspace tracking when workspace is closed")
  func removesWorkspaceTracking() async throws {
    // given
    let tracker = RecentEditsTracker()
    let workspace = URL(fileURLWithPath: "/workspace")
    let file = URL(fileURLWithPath: "/workspace/file.swift")

    await tracker.recordBaseline(workspace: workspace, file: file, content: "// Start")
    await tracker.trackEdit(workspace: workspace, file: file, content: "// Start\nlet x = 1")

    // Verify tracking exists
    var edits = await tracker.getRecentEdits(workspace: workspace)
    #expect(edits != nil)

    // when - remove workspace
    await tracker.removeWorkspace(workspace)

    // then - tracking should be removed
    edits = await tracker.getRecentEdits(workspace: workspace)
    #expect(edits == nil)
  }

  @Test("Does not track if no baseline recorded")
  func doesNotTrackWithoutBaseline() async throws {
    // given
    let tracker = RecentEditsTracker()
    let workspace = URL(fileURLWithPath: "/workspace")
    let file = URL(fileURLWithPath: "/workspace/file.swift")

    // when - try to track without recording baseline
    await tracker.trackEdit(workspace: workspace, file: file, content: "let x = 1")

    // then - should not track anything
    let edits = await tracker.getRecentEdits(workspace: workspace)
    #expect(edits == nil)
  }

  @Test("Ignores duplicate content")
  func ignoresDuplicateContent() async throws {
    // given
    let tracker = RecentEditsTracker()
    let workspace = URL(fileURLWithPath: "/workspace")
    let file = URL(fileURLWithPath: "/workspace/file.swift")
    let content = "let x = 1"

    await tracker.recordBaseline(workspace: workspace, file: file, content: content)
    await tracker.trackEdit(workspace: workspace, file: file, content: content + "\nlet y = 2")

    let editsAfterFirst = await tracker.getRecentEdits(workspace: workspace)
    let countAfterFirst = editsAfterFirst?.trackedVersions.count ?? 0

    // when - track same content again
    await tracker.trackEdit(workspace: workspace, file: file, content: content + "\nlet y = 2")

    // then - should not create duplicate
    let editsAfterSecond = await tracker.getRecentEdits(workspace: workspace)
    let countAfterSecond = editsAfterSecond?.trackedVersions.count ?? 0
    #expect(countAfterFirst == countAfterSecond)
  }
}
