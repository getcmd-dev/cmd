// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Combine
import ConcurrencyFoundation
import Foundation
import FoundationInterfaces
import LoggingServiceInterface
import ShellServiceInterface
import ThreadSafe
import XcodeObserverServiceInterface
import XcodeProj

// MARK: - FileLister

/// A helper class to list files in a workspace.
@ThreadSafe
final class FileLister: Sendable {
  init(fileManager: FileManagerI, shellService: ShellService) {
    self.fileManager = fileManager
    self.shellService = shellService
  }

  func listFiles(in workspace: URL, debounce: TimeInterval?) async throws -> ListFilesResult {
    let (promise, completion) = Future<ListFilesResult, Error>.make()
    inLock {
      $0.debouncedTasks[workspace] = $0.debouncedTasks[workspace, default: []]
      $0.debouncedTasks[workspace, default: []].append(completion)
    }
    if let debounce {
      Task { [weak self] in
        try await Task.sleep(nanoseconds: UInt64(debounce * 1_000_000_000))
        await self?.immediatelyListFilesAndResolveTasks(workspace: workspace)
      }
    } else {
      await immediatelyListFilesAndResolveTasks(workspace: workspace)
    }
    return try await promise.value
  }

  private let fileManager: FileManagerI
  private let shellService: ShellService

  private var debouncedTasks = [URL: [@Sendable (Result<ListFilesResult, any Error>) -> Void]]()
  private var isListingFilesForWorkspaces = Set<URL>()

  private func immediatelyListFilesAndResolveTasks(workspace: URL) async {
    let shouldRun = inLock { state in
      // If we are already listing files for this workspace, we don't do it a second time concurrently.
      let shouldRun = !state.isListingFilesForWorkspaces.contains(workspace) &&
        // It is possible that all the scheduled tasks have already been completed by an earlier run. Nothing to do if nil.
        state.debouncedTasks[workspace] != nil
      state.isListingFilesForWorkspaces.insert(workspace)
      return shouldRun
    }
    guard shouldRun else {
      return
    }
    let result: Result<ListFilesResult, any Error>
    do {
      result = try await .success(immediatelyListFiles(in: workspace))
    } catch {
      result = .failure(error)
    }
    let completions = inLock { state in
      state.isListingFilesForWorkspaces.remove(workspace)
      let completions = state.debouncedTasks[workspace] ?? []
      state.debouncedTasks[workspace] = nil
      return completions
    }
    for completion in completions {
      completion(result)
    }
  }

  private func immediatelyListFiles(in workspace: URL) async throws -> ListFilesResult {
    let workspaceType: WorkspaceType
    let files: [URL]
    // When an .xcworkspace is opened, we look for the corresponding .xcodeproj which is where the project structure is defined.
    // `XcodeProj` only works with an .xcodeproj file.
    if let xcodeProj = try? XcodeProj(path: .init(workspace.path.replacingOccurrences(of: ".xcworkspace", with: ".xcodeproj"))) {
      workspaceType = .xcodeProject
      let rootDir = workspace.deletingLastPathComponent()
      files = listFilesAvailable(inProject: xcodeProj, in: rootDir)
    } else if workspace.lastPathComponent == "Package.swift" {
      workspaceType = .swiftPackage
      files = try await listFilesAvailable(inPackage: workspace)
    } else {
      workspaceType = .directory
      let packagePath = workspace.appendingPathComponent("Package.swift")
      if fileManager.fileExists(atPath: packagePath.path) {
        files = try await listFilesAvailable(inPackage: packagePath)
      } else {
        files = listFilesAvailable(inDirectory: workspace)
      }
    }
    let workspaceRoot = workspaceType == .xcodeProject ? workspace.deletingLastPathComponent() : workspace
    let filteredFiles = await files.filterOutIgnoredFiles(root: workspaceRoot, shellService: shellService)
    let uniqueFiles = Set(filteredFiles.map(\.standardized))
    return ListFilesResult(
      files: Array(uniqueFiles),
      workspaceType: workspaceType,
      workspaceRoot: workspaceRoot)
  }

  private func listFilesAvailable(inProject xcodeproj: XcodeProj, in projectDir: URL) -> [URL] {
    var files = [URL]()
    let addFileRef: (PBXFileReference) -> Void = { fileRef in
      if
        let pathStr = fileRef.path,
        var path = URL(string: pathStr),
        !["app", "appex", "framework"].contains(path.pathExtension)
      {
        var parent = fileRef.parent
        while
          let parentPathStr = parent?.path,
          let parentPath = URL(string: parentPathStr)
        {
          path = path.resolve(from: parentPath)
          parent = parent?.parent
        }

        path = path.resolve(from: projectDir)

        if fileRef.lastKnownFileType == "wrapper" {
          files.append(contentsOf: self.listFilesAvailable(inDirectory: path))
        } else {
          files.append(path)
        }
      }
    }

    xcodeproj.pbxproj.fileReferences.forEach(addFileRef)

    var queue = xcodeproj.pbxproj.groups
    while !queue.isEmpty {
      let group = queue.removeFirst()
      for child in group.children {
        if let fileRef = child as? PBXFileReference {
          addFileRef(fileRef)
        } else if let group = child as? PBXGroup {
          queue.append(group)
        } else if let referenceProxy = child as? PBXReferenceProxy {
          print(referenceProxy)
          // Handle reference proxy
        } else if let variantGroup = child as? PBXVariantGroup {
          print(variantGroup)
          // Handle variant group
        } else if let folderRef = child as? PBXFileSystemSynchronizedRootGroup {
          if let path = folderRef.path {
            let folderPath = path.resolvePath(from: projectDir)
            files.append(contentsOf: listFilesAvailable(inDirectory: folderPath))
          }
        }
      }
    }
    return files
  }

  private func listFilesAvailable(inPackage packagePath: URL) async throws -> [URL] {
    let dirPath = packagePath.deletingLastPathComponent()
    let output = try await shellService.run("swift package describe --type json", cwd: dirPath.path)

    // swift can output warnings to stdout, which breaks json parsing
    // https://github.com/swiftlang/swift-package-manager/issues/8402
    var lines = output.stdout?.split(separator: "\n")
    while lines?.first != nil {
      if lines?.first?.hasPrefix("{") == true {
        break
      }
      lines?.removeFirst()
    }
    guard let stdout = lines?.joined(separator: "\n").utf8Data else {
      assertionFailure("Failed to convert output to Data")
      return []
    }
    let packageContent = try JSONDecoder().decode(SPMPackageDescription.self, from: stdout)
    var files = packageContent.targets?
      .flatMap { target -> [URL] in
        let targetPath = target.path.resolvePath(from: dirPath)
        return ((target.sources ?? []) + (target.resources?.map(\.path) ?? []))
          .map { $0.resolvePath(from: targetPath) }
      } ?? []
    files.append(packagePath)
    return files
  }

  private func listFilesAvailable(inDirectory directoryPath: URL) -> [URL] {
    var suggestions = [URL]()
    if
      let enumerator = fileManager.enumerator(
        at: directoryPath,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants])
    {
      for case let fileURL as URL in enumerator {
        do {
          // Check if this is a directory we want to skip
          let fileName = fileURL.lastPathComponent
          if fileURL.hasDirectoryPath, fileName == ".build" {
            enumerator.skipDescendants()
            continue
          }

          let fileAttributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
          if fileAttributes.isRegularFile == true {
            suggestions.append(fileURL)
          }
        } catch { }
      }
    }
    return suggestions
  }
}

// MARK: - SPMPackageDescription

struct SPMPackageDescription: Decodable {
  let targets: [Target]?

  struct Target: Decodable {
    let path: String
    let sources: [String]?
    let resources: [Resource]?

    struct Resource: Decodable {
      let path: String
    }
  }
}

extension [URL] {
  /// Exclude files that are git ignored, or match common ignore patterns when not in a git repo.
  /// - Parameters:
  ///   - root: The root of the repo from where we should check for the existence of a git repo
  ///   - Returns: The current array without files not tracked by git, or not part of usually ignored files when not in a git repo.
  func filterOutIgnoredFiles(root: URL, shellService: ShellService) async -> [URL] {
    let isGitRepo = await {
      do {
        try await shellService.runAndThrow("git rev-parse --show-toplevel", cwd: root.path)
        return true
      } catch {
        return false
      }
    }()
    guard isGitRepo else {
      #if DEBUG
      /// Skip common pattern filtering for test bundles to avoid filtering test resources
      /// (tests run from DerivedData (xcode) or .build (spm))
      let isTestBundle = root.path.contains(".xctest") || root.path.contains("-tool.bundle")
      if isTestBundle {
        return self
      }
      #endif
      return self.filter({ !shouldLikelyIgnoreFile($0) })
    }
    let untrackedFiles = try? await Set(shellService.runAndThrow(
      "echo '\(self.map(\.path).joined(separator: "\n"))' | git check-ignore --stdin",
      cwd: root.path)?
      .split(separator: "\n")
      .map(String.init) ?? [])
    // git check-ignore exit with status 1 when no files are ignored. This is an expected error
    return self.filter({ untrackedFiles?.contains($0.path) != true })
  }

  /// Check if a file should be ignored based on common patterns
  func shouldLikelyIgnoreFile(_ url: URL) -> Bool {
    let path = url.path
    let pathComponents = url.pathComponents

    // Ignore hidden files and directories (starting with .)
    if pathComponents.contains(where: { $0.hasPrefix(".") && $0 != "." }) {
      return true
    }
    if url.pathExtension == "mlmodel" {
      return true
    }

    // Ignore common build and dependency directories
    let ignoredDirectories = [
      ".build",
      "build",
      "DerivedData",
      "xcuserdata",
      "node_modules",
      ".swiftpm",
      "bower_components",
      "Preview Content",
      "tmp",
    ]
    if pathComponents.contains(where: { ignoredDirectories.contains($0) }) {
      return true
    }

    // Ignore temporary and backup files
    if path.hasSuffix("~") || path.hasSuffix(".swp") || path.hasSuffix(".tmp") {
      return true
    }

    return false
  }

}
