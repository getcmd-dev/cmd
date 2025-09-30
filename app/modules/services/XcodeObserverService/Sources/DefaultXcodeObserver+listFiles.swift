// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import XcodeObserverServiceInterface
import XcodeProj

extension DefaultXcodeObserver {
  func listFiles(in workspace: URL) async throws -> ([URL], WorkspaceType) {
    let workspaceType: WorkspaceType
    let files: [URL]
    if let xcodeProj = try? XcodeProj(path: .init(workspace.path)) {
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
    let uniqueFiles = Set(files.map(\.standardized))
    return (Array(uniqueFiles), workspaceType)
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
