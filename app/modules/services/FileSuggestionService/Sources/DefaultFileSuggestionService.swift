// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
@preconcurrency import Combine
import ConcurrencyFoundation
import FileSuggestionServiceInterface
import Foundation
import Ifrit
import ThreadSafe
import XcodeObserverServiceInterface

// MARK: - DefaultFileSuggestionService

@ThreadSafe
final class DefaultFileSuggestionService: FileSuggestionService {

  init(
    xcodeObserver: XcodeObserver)
  {
    self.xcodeObserver = xcodeObserver
  }

  func suggestFiles(for query: String, in workspaceURL: URL, top: Int) async throws -> [FileSuggestion] {
    let files = try await usingCachingListFilesAvailable(in: workspaceURL)
    if query == "" {
      return Array(
        files
          .sorted(by: { $0.displayPath < $1.displayPath })
          .prefix(top))
    }
    let fuse = Fuse(threshold: 1.0, qos: .userInitiated)

    let resultsWithScore = await fuse.search(String(query.reversed()), in: files.map { String($0.displayPath.reversed()) })
      .map { result -> (FileSuggestion, Double, Int) in
        let suggestion = files[result.index]
        let score = result.diffScore // lower is better
        let longestMatch = result.ranges.reduce(0) { max($0, $1.count) }
        return (
          FileSuggestion(path: suggestion.path, displayPath: suggestion.displayPath, matchedRanges: result.ranges),
          score,
          longestMatch)
      }
      .sorted { lhs, rhs in
        if lhs.1 == rhs.1 {
          return lhs.0.displayPath < rhs.0.displayPath
        }
        return lhs.1 < rhs.1
      }
      .prefix(top)
    let resultsWithScore2 = Array(resultsWithScore)

    let results = zip(resultsWithScore2 + [nil], [nil] + resultsWithScore2)
      .filter { (current: (FileSuggestion, Double, Int)?, previous: (FileSuggestion, Double, Int)?) in
        guard let current, let previous else { return true }
        return current.2 >= previous.2 - 2
      }
      .compactMap(\.0?.0)
    return Array(results)
  }

  private struct CachedFileResult: Sendable {
    let files: [FileSuggestion]
    let cachedAt: Date
  }

  /// The strategy to list available files without overloading the system.
  /// The enum is only used to help with compilation.
  private enum HowToListAvailableFiles {
    case inflightTask(_ task: Future<[FileSuggestion], Error>)
    case cachedResult(_ result: [FileSuggestion])
    case newTask(_ task: (Future<[FileSuggestion], Error>, @Sendable (Result<[FileSuggestion], Error>) -> Void))
  }

  private let xcodeObserver: XcodeObserver

  private var inflightTasks = [URL: Future<[FileSuggestion], Error>]()
  private var cachedFiles = [URL: CachedFileResult]()

  /// List files available in the project.
  /// As this can be called quickly in a row (as the user update their search), this method is mindful about resource usage.
  private func usingCachingListFilesAvailable(in workspace: URL) async throws -> [FileSuggestion] {
    let listFiles: HowToListAvailableFiles = inLock { state in
      if let inflightTask = state.inflightTasks[workspace] {
        // Merge inflight tasks to avoid multiple calls.
        return .inflightTask(inflightTask)
      }
      if let cachedResult = state.cachedFiles[workspace], Date().timeIntervalSince(cachedResult.cachedAt) < 10 {
        // Return recent enough results.
        return .cachedResult(cachedResult.files)
      }

      // Fallback to new task.
      let (future, promise) = Future<[FileSuggestion], Error>.make()
      state.inflightTasks[workspace] = future
      return .newTask((future, promise))
    }

    switch listFiles {
    case .inflightTask(let inflightTask):
      return try await inflightTask.value
    case .cachedResult(let cachedResult):
      return cachedResult
    case .newTask(let (future, promise)):
      let allowedExtensions = textFileExtensions
      let ignoredDirectories = Set([".build", "build", "xcuserdata", "DerivedData"])
      Task.detached(priority: .userInitiated) {
        do {
          let files = try await self.listFilesAvailable(in: workspace)
            .filter { suggestion in
              allowedExtensions.contains(suggestion.path.pathExtension)
            }
            .filter { suggestion in
              #if DEBUG
              // For tests, the resources might be copied to a .build / DerivedData subfolder. To keep the test working, do some extra checks.
              if suggestion.path.path.contains("FileSuggestionServiceTests") {
                return suggestion.path.pathComponents.contains(where: { Set(["build", "xcuserdata"]).contains($0) }) == false
              }
              #endif
              return suggestion.path.pathComponents.contains(where: { ignoredDirectories.contains($0) }) == false
            }
          self.cachedFiles[workspace] = CachedFileResult(files: files, cachedAt: Date())
          self.inflightTasks[workspace] = nil
          promise(.success(files))
        } catch {
          self.inflightTasks[workspace] = nil
          promise(.failure(error))
        }
      }
      return try await future.value
    }
  }

  /// List all available files in the project.
  private func listFilesAvailable(in workspace: URL) async throws -> [FileSuggestion] {
    let rootDir: URL
    let (files, workspaceType) = try await xcodeObserver.listFiles(in: workspace)
    switch workspaceType {
    case .xcodeProject:
      rootDir = workspace.deletingLastPathComponent()
    case .swiftPackage:
      rootDir = workspace.deletingLastPathComponent()
    case .directory:
      rootDir = workspace
    }

    return files.map { file in
      let relativePath = file.pathRelative(to: rootDir)
      return FileSuggestion(path: file, displayPath: relativePath, matchedRanges: [])
    }
  }

}
