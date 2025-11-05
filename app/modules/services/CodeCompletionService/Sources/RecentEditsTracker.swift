// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import FileDiffFoundation
import Foundation

/// Represents a snapshot of a file at a specific point in time
public struct FileVersion: Sendable {
  public let fileURL: URL
  public let content: String
  public let timestamp: Date
  /// Cached diff line count compared to the baseline (oldest tracked version or initial state)
  public let diffLines: Int

  public init(fileURL: URL, content: String, timestamp: Date, diffLines: Int) {
    self.fileURL = fileURL
    self.content = content
    self.timestamp = timestamp
    self.diffLines = diffLines
  }
}

/// Tracks recent edits for a single workspace
public struct WorkspaceRecentEdits: Sendable {
  /// Primary list: versions within budget (most recent first)
  public var trackedVersions: [FileVersion] = []

  /// Buffer: additional versions that were pushed out due to budget constraints
  public var bufferVersions: [FileVersion] = []

  /// Total budget in diff lines
  public let budget: Int

  /// Current budget usage (sum of diffLines in trackedVersions)
  public var currentUsage: Int {
    trackedVersions.reduce(0) { $0 + $1.diffLines }
  }

  public init(budget: Int = 100) {
    self.budget = budget
  }
}

/// Tracks recent file edits per workspace, maintaining a history within a budget constraint
public actor RecentEditsTracker {
  /// Track recent edits per workspace
  private var workspaceEdits = [URL: WorkspaceRecentEdits]()

  /// Track baseline content per file (the initial didOpen state)
  private var fileBaselines = [URL: [URL: String]]()

  /// Budget for each workspace in diff lines
  private let budget: Int

  public init(budget: Int = 100) {
    self.budget = budget
  }

  /// Records the baseline content when a file is first opened
  public func recordBaseline(workspace: URL, file: URL, content: String) {
      fileBaselines[workspace] = fileBaselines[workspace, default: [:]]
    // Only record if we don't already have a baseline for this file
    if fileBaselines[workspace]?[file] == nil {
      fileBaselines[workspace]?[file] = content
    }
  }

  /// Updates recent edits tracking for a file change
  public func trackEdit(workspace: URL, file: URL, content: String) {
    // Get existing edits if they exist
    var edits = workspaceEdits[workspace]

    // Find the most recent version of this file (if any) and all versions for this file
    let fileVersions = edits?.trackedVersions.filter { $0.fileURL == file } ?? []
    let mostRecentVersion = fileVersions.first

    // Check if content actually changed
    if let mostRecent = mostRecentVersion, mostRecent.content == content {
      return // No change
    }

    // Determine the baseline for computing diff
    // If we have tracked versions, use the oldest one; otherwise use the baseline
    let oldestTrackedVersion = fileVersions.last
    let baselineContent: String
    if let oldest = oldestTrackedVersion {
      baselineContent = oldest.content
    } else if let baseline = fileBaselines[workspace]?[file] {
      baselineContent = baseline
    } else {
      // No baseline available, skip tracking
      return
    }

    // Initialize workspace edits if needed (after we know we have a baseline)
    if edits == nil {
      edits = WorkspaceRecentEdits(budget: budget)
    }

    guard var editsUnwrapped = edits else { return }

    // Compute diff from baseline to current state
    let diffLines = computeDiffLineCount(old: baselineContent, new: content)

    // Create new version
    let newVersion = FileVersion(
      fileURL: file,
      content: content,
      timestamp: Date(),
      diffLines: diffLines
    )

    // Remove old versions of this file from tracked list
    editsUnwrapped.trackedVersions.removeAll { $0.fileURL == file }

    // Update the edits structure
    workspaceEdits[workspace] = editsUnwrapped

    // Try to fit the new version within budget
    pruneToFitBudget(workspace: workspace, newVersion: newVersion)

    // If the new change reduced the diff (e.g., undo), try restoring from buffer
    if let previous = mostRecentVersion, diffLines < previous.diffLines {
      tryRestoreFromBuffer(workspace: workspace)
    }
  }

  /// Removes tracking for a workspace (e.g., when workspace is closed)
  public func removeWorkspace(_ workspace: URL) {
    workspaceEdits.removeValue(forKey: workspace)
    fileBaselines.removeValue(forKey: workspace)
  }

  /// Gets the recent edits for a workspace
  public func getRecentEdits(workspace: URL) -> WorkspaceRecentEdits? {
    workspaceEdits[workspace]
  }

  // MARK: - Private Helpers

  /// Computes the number of diff lines between old and new content
  private func computeDiffLineCount(old: String, new: String) -> Int {
    do {
      let diff = try FileDiff.getGitDiff(oldContent: old, newContent: new)
      // Count lines that start with +, -, or @@ (change/hunk markers)
      let lines = diff.split(separator: "\n", omittingEmptySubsequences: false)
      return lines.filter { line in
        line.hasPrefix("+") || line.hasPrefix("-") || line.hasPrefix("@@")
      }.count
    } catch {
      // If diff computation fails, estimate conservatively
      print("Failed to compute diff: \(error)")
      return budget // Return max budget to avoid tracking this change
    }
  }

  /// Prunes tracked versions to fit the new version within budget
  /// Moves pruned versions to buffer
  private func pruneToFitBudget(workspace: URL, newVersion: FileVersion) {
    guard var edits = workspaceEdits[workspace] else { return }

    let newUsage = edits.currentUsage + newVersion.diffLines

    if newUsage <= edits.budget {
      // New version fits within budget, just add it
      edits.trackedVersions.insert(newVersion, at: 0)
    } else {
      // Need to prune old versions
      var remainingBudget = edits.budget - newVersion.diffLines
      var keptVersions: [FileVersion] = []
      var movedToBuffer: [FileVersion] = []

      for version in edits.trackedVersions {
        if remainingBudget >= version.diffLines {
          keptVersions.append(version)
          remainingBudget -= version.diffLines
        } else {
          movedToBuffer.append(version)
        }
      }

      edits.trackedVersions = [newVersion] + keptVersions
      // Add to front of buffer (most recent pruned versions first)
      edits.bufferVersions = movedToBuffer + edits.bufferVersions

      // Limit buffer size to budget worth of changes
      var bufferUsage = 0
      var trimmedBuffer: [FileVersion] = []
      for version in edits.bufferVersions {
        if bufferUsage + version.diffLines <= edits.budget {
          trimmedBuffer.append(version)
          bufferUsage += version.diffLines
        } else {
          break
        }
      }
      edits.bufferVersions = trimmedBuffer
    }

    workspaceEdits[workspace] = edits
  }

  /// Tries to restore versions from buffer when budget is available
  private func tryRestoreFromBuffer(workspace: URL) {
    guard var edits = workspaceEdits[workspace] else { return }
    guard !edits.bufferVersions.isEmpty else { return }

    var availableBudget = edits.budget - edits.currentUsage
    var restoredVersions: [FileVersion] = []
    var remainingBuffer: [FileVersion] = []

    for version in edits.bufferVersions {
      if availableBudget >= version.diffLines {
        restoredVersions.append(version)
        availableBudget -= version.diffLines
      } else {
        remainingBuffer.append(version)
      }
    }

    if !restoredVersions.isEmpty {
      edits.trackedVersions.append(contentsOf: restoredVersions)
      edits.bufferVersions = remainingBuffer
      workspaceEdits[workspace] = edits
    }
  }
}
