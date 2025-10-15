// swiftformat:disable all

// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import SwiftModule

// MARK: - SyncTests

@MainActor
@Suite("SyncTests", .serialized)
struct SyncTests {
    
    @Test("Doesn't change an up-to-date repo")
    func doesntChangeAUpToDateRepo() throws {
      // Given
      let repoURL = try findRepo(named: "test-repo-1")
      let mockFileManager = MockFileManager(copyingRepoAt: repoURL)
      fileManager = mockFileManager
      let before = mockFileManager.files

      // When
      _ = try UpdateDependencies.update(packageURL: URL(filePath: "/repo/Package.swift"), all: true)

      // Then
      let diff = try diffFiles(before: before, after: mockFileManager.files)
      #expect(diff == "")
    }
    
    @Test("Doesn't change a repo with trivia only changes")
    func doesntChangeARepoWithTriviaOnlyChanges() throws {
      // Given
      let repoURL = try findRepo(named: "test-repo-1")
      let mockFileManager = MockFileManager(copyingRepoAt: repoURL)
      fileManager = mockFileManager
        
        var moduleAPackage = try #require( mockFileManager.files["/repo/ModuleA/Package.swift"])
        moduleAPackage = "\n" + moduleAPackage + "\n// some comment\n"
        try mockFileManager.write(moduleAPackage, to: URL(filePath: "/repo/ModuleA/Package.swift"), atomically: true, encoding: .utf8)
        
        var moduleBModule = try #require( mockFileManager.files["/repo/ModuleB/Module.swift"])
        moduleBModule = "\n" + moduleBModule + "\n// some comment\n".replacingOccurrences(of: "name:", with: "       name:")
        try mockFileManager.write(moduleBModule, to: URL(filePath: "/repo/ModuleB/Module.swift"), atomically: true, encoding: .utf8)
        
      let before = mockFileManager.files

      // When
      _ = try UpdateDependencies.update(packageURL: URL(filePath: "/repo/Package.swift"), all: true)

      // Then
      let diff = try diffFiles(before: before, after: mockFileManager.files)
      #expect(diff == "")
    }

  @Test("Add missing dependency to module file")
  func addMissingDependencyToModuleFile() throws {
    // Given
    let repoURL = try findRepo(named: "test-repo-1")
    let mockFileManager = MockFileManager(copyingRepoAt: repoURL)
    fileManager = mockFileManager
    // Remove dependency on ModuleA from ModuleB from Module.swift
    try mockFileManager.remove(line: "\"ModuleA\",", in: "/repo/ModuleB/Module.swift")
    let before = mockFileManager.files

    // When
    _ = try UpdateDependencies.update(packageURL: URL(filePath: "/repo/Package.swift"), all: true)

    // Then
    let diff = try diffFiles(before: before, after: mockFileManager.files)
    let expected = """
      diff --git a/ModuleB/Module.swift b/ModuleB/Module.swift
      --- a/ModuleB/Module.swift
      +++ b/ModuleB/Module.swift
      @@ -1,4 +1,5 @@
       Target.module(
         name: "ModuleB",
         dependencies: [
      +  "ModuleA",
       ])
      """
    #expect(diff == expected)
  }

  @Test("Remove extra dependency from module file")
  func removeExtraDependencyFromModuleFile() throws {
    // Given
    let repoURL = try findRepo(named: "test-repo-1")
    let mockFileManager = MockFileManager(copyingRepoAt: repoURL)
    fileManager = mockFileManager
    // Remove dependency on ModuleA from ModuleB from Module.swift
    try mockFileManager.remove(line: "import ModuleA", in: "/repo/ModuleB/Sources/Source.swift")
    let before = mockFileManager.files

    // When
    _ = try UpdateDependencies.update(packageURL: URL(filePath: "/repo/Package.swift"), all: true)

    // Then
    let diff = try diffFiles(before: before, after: mockFileManager.files)
    let expected = """
      diff --git a/ModuleB/Module.swift b/ModuleB/Module.swift
      --- a/ModuleB/Module.swift
      +++ b/ModuleB/Module.swift
      @@ -1,5 +1,3 @@
       Target.module(
         name: "ModuleB",
      -  dependencies: [
      -  "ModuleA",
      -])
      +  dependencies: [])
      diff --git a/ModuleB/Package.swift b/ModuleB/Package.swift
      --- a/ModuleB/Package.swift
      +++ b/ModuleB/Package.swift
      @@ -108,9 +108,7 @@ var targets = [Target]()
       targets.append(
         contentsOf: Target.module(
           name: "ModuleB",
      -    dependencies: [
      -      .product(name: "ModuleA", package: "ModuleA")
      -    ],
      +    dependencies: [],
           path: "."))
       
       let package = Package(
      @@ -121,7 +119,5 @@ let package = Package(
         products: [
           .library(name: "ModuleB", targets: ["ModuleB"])
         ],
      -  dependencies: [
      -    .package(path: "../ModuleA")
      -  ],
      +  dependencies: [],
         targets: targets)
      diff --git a/Package.swift b/Package.swift
      --- a/Package.swift
      +++ b/Package.swift
      @@ -117,9 +117,7 @@ targets.append(
       targets.append(
         contentsOf: Target.module(
           name: "ModuleB",
      -    dependencies: [
      -      "ModuleA"
      -    ],
      +    dependencies: [],
           path: "./ModuleB"))
       
       let package = Package(
      """

    #expect(diff == expected)
  }
    
    @Test("Add tests if Test/ is not empty")
    func addTestsIfTestFolderIsNotEmpty() throws {
      // Given
      let repoURL = try findRepo(named: "test-repo-1")
      let mockFileManager = MockFileManager(copyingRepoAt: repoURL)
      fileManager = mockFileManager
      // Add a test file to /ModuleB/Tests/
        try mockFileManager.write("", to: URL(filePath: "/repo/ModuleB/Tests/Tests.swift"), atomically: true, encoding: .utf8)
      let before = mockFileManager.files

      // When
      _ = try UpdateDependencies.update(packageURL: URL(filePath: "/repo/Package.swift"), all: true)

      // Then
      let diff = try diffFiles(before: before, after: mockFileManager.files)
      let expected = """
        diff --git a/ModuleB/Module.swift b/ModuleB/Module.swift
        --- a/ModuleB/Module.swift
        +++ b/ModuleB/Module.swift
        @@ -2,4 +2,5 @@ Target.module(
           name: "ModuleB",
           dependencies: [
           "ModuleA",
        -])
        +],
        +  testsDependencies: [])
        diff --git a/ModuleB/Package.swift b/ModuleB/Package.swift
        --- a/ModuleB/Package.swift
        +++ b/ModuleB/Package.swift
        @@ -111,6 +111,7 @@ targets.append(
             dependencies: [
               .product(name: "ModuleA", package: "ModuleA")
             ],
        +    testsDependencies: [],
             path: "."))
         
         let package = Package(
        diff --git a/Package.swift b/Package.swift
        --- a/Package.swift
        +++ b/Package.swift
        @@ -120,6 +120,7 @@ targets.append(
             dependencies: [
               "ModuleA"
             ],
        +    testsDependencies: [],
             path: "./ModuleB"))
         
         let package = Package(
        """
      #expect(diff == expected)
    }
    
    @Test("Remote tests if Test/ is empty")
    func removeTestsIfTestFolderIsEmpty() throws {
      // Given
      let repoURL = try findRepo(named: "test-repo-1")
      let mockFileManager = MockFileManager(copyingRepoAt: repoURL)
      fileManager = mockFileManager
      // Remove the only test file in /ModuleA/Tests/
        try mockFileManager.removeItem(atPath: "/repo/ModuleA/Tests/Tests.swift")
      let before = mockFileManager.files

      // When
      _ = try UpdateDependencies.update(packageURL: URL(filePath: "/repo/Package.swift"), all: true)

      // Then
      let diff = try diffFiles(before: before, after: mockFileManager.files)
      let expected = """
        diff --git a/ModuleA/Module.swift b/ModuleA/Module.swift
        --- a/ModuleA/Module.swift
        +++ b/ModuleA/Module.swift
        @@ -1,6 +1,3 @@
         Target.module(
           name: "ModuleA",
        -  dependencies: [],
        -  testsDependencies: [
        -  .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        -])
        +  dependencies: [])
        diff --git a/ModuleA/Package.swift b/ModuleA/Package.swift
        --- a/ModuleA/Package.swift
        +++ b/ModuleA/Package.swift
        @@ -109,9 +109,6 @@ targets.append(
           contentsOf: Target.module(
             name: "ModuleA",
             dependencies: [],
        -    testsDependencies: [
        -      .product(name: "DependenciesTestSupport", package: "swift-dependencies")
        -    ],
             path: "."))
         
         let package = Package(
        diff --git a/Package.swift b/Package.swift
        --- a/Package.swift
        +++ b/Package.swift
        @@ -109,9 +109,6 @@ targets.append(
           contentsOf: Target.module(
             name: "ModuleA",
             dependencies: [],
        -    testsDependencies: [
        -      .product(name: "DependenciesTestSupport", package: "swift-dependencies")
        -    ],
             path: "./ModuleA"))
         
         targets.append(
        """
      #expect(diff == expected)
    }
    
    @Test("Initializes Module.swift when the file is created")
    func initializeModuleFile() throws {
      // Given
      let repoURL = try findRepo(named: "test-repo-1")
      let mockFileManager = MockFileManager(copyingRepoAt: repoURL)
      fileManager = mockFileManager
      // Add a module file to /ModuleC
        try mockFileManager.write("", to: URL(filePath: "/repo/ModuleC/Module.swift"), atomically: true, encoding: .utf8)
      let before = mockFileManager.files

      // When
      _ = try UpdateDependencies.update(packageURL: URL(filePath: "/repo/Package.swift"), all: true)

      // Then
        let newPackageFile = "/repo/ModuleC/Package.swift"
        #expect(mockFileManager.files[newPackageFile] != nil)
        let diff = try diffFiles(before: before, after: mockFileManager.files.filter { $0.key != newPackageFile})
      let expected = """
        diff --git a/ModuleC/Module.swift b/ModuleC/Module.swift
        --- a/ModuleC/Module.swift
        +++ b/ModuleC/Module.swift
        @@ -0,0 +1,2 @@
        +Target.module(
        +  name: "ModuleC")
        diff --git a/Package.swift b/Package.swift
        --- a/Package.swift
        +++ b/Package.swift
        @@ -122,6 +122,11 @@ targets.append(
             ],
             path: "./ModuleB"))
         
        +targets.append(
        +  contentsOf: Target.module(
        +    name: "ModuleC",
        +    path: "./ModuleC"))
        +
         let package = Package(
           name: "Packages",
           platforms: [
        """
      #expect(diff == expected)
    }
    
    @Test("Removing external dependency")
    func removeExternalDependency() throws {
        let repoURL = try findRepo(named: "test-repo-1")
        let mockFileManager = MockFileManager(copyingRepoAt: repoURL)
        fileManager = mockFileManager
        // Remove dependency on ModuleA from ModuleB from Module.swift
        try mockFileManager.remove(line: "import DependenciesTestSupport", in: "/repo/ModuleA/Tests/Tests.swift")
        let before = mockFileManager.files

        // When
        _ = try UpdateDependencies.update(packageURL: URL(filePath: "/repo/Package.swift"), all: true)

        // Then
        let diff = try diffFiles(before: before, after: mockFileManager.files)
        let expected = """
            diff --git a/ModuleA/Module.swift b/ModuleA/Module.swift
            --- a/ModuleA/Module.swift
            +++ b/ModuleA/Module.swift
            @@ -1,6 +1,4 @@
             Target.module(
               name: "ModuleA",
               dependencies: [],
            -  testsDependencies: [
            -  .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
            -])
            +  testsDependencies: [])
            diff --git a/ModuleA/Package.swift b/ModuleA/Package.swift
            --- a/ModuleA/Package.swift
            +++ b/ModuleA/Package.swift
            @@ -109,9 +109,7 @@ targets.append(
               contentsOf: Target.module(
                 name: "ModuleA",
                 dependencies: [],
            -    testsDependencies: [
            -      .product(name: "DependenciesTestSupport", package: "swift-dependencies")
            -    ],
            +    testsDependencies: [],
                 path: "."))
             
             let package = Package(
            diff --git a/Package.swift b/Package.swift
            --- a/Package.swift
            +++ b/Package.swift
            @@ -109,9 +109,7 @@ targets.append(
               contentsOf: Target.module(
                 name: "ModuleA",
                 dependencies: [],
            -    testsDependencies: [
            -      .product(name: "DependenciesTestSupport", package: "swift-dependencies")
            -    ],
            +    testsDependencies: [],
                 path: "./ModuleA"))
             
             targets.append(
            """
        #expect(diff == expected)
    }
    
    @Test("Add known external dependency")
    func addKnownExternalDependency() throws {
        let repoURL = try findRepo(named: "test-repo-1")
        let mockFileManager = MockFileManager(copyingRepoAt: repoURL)
        fileManager = mockFileManager
        // Remove dependency on ModuleA from ModuleB from Module.swift
        try mockFileManager.write("import DependenciesTestSupport", to: URL(filePath: "/repo/ModuleB/Tests/Tests.swift"), atomically: true, encoding: .utf8)
        let before = mockFileManager.files

        // When
        _ = try UpdateDependencies.update(packageURL: URL(filePath: "/repo/Package.swift"), all: true)

        // Then
        let diff = try diffFiles(before: before, after: mockFileManager.files)
        let expected = """
            diff --git a/ModuleB/Module.swift b/ModuleB/Module.swift
            --- a/ModuleB/Module.swift
            +++ b/ModuleB/Module.swift
            @@ -2,4 +2,7 @@ Target.module(
               name: "ModuleB",
               dependencies: [
               "ModuleA",
            +],
            +  testsDependencies: [
            +  .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
             ])
            diff --git a/ModuleB/Package.swift b/ModuleB/Package.swift
            --- a/ModuleB/Package.swift
            +++ b/ModuleB/Package.swift
            @@ -111,6 +111,9 @@ targets.append(
                 dependencies: [
                   .product(name: "ModuleA", package: "ModuleA")
                 ],
            +    testsDependencies: [
            +      .product(name: "DependenciesTestSupport", package: "swift-dependencies")
            +    ],
                 path: "."))
             
             let package = Package(
            diff --git a/Package.swift b/Package.swift
            --- a/Package.swift
            +++ b/Package.swift
            @@ -120,6 +120,9 @@ targets.append(
                 dependencies: [
                   "ModuleA"
                 ],
            +    testsDependencies: [
            +      .product(name: "DependenciesTestSupport", package: "swift-dependencies")
            +    ],
                 path: "./ModuleB"))
             
             let package = Package(
            """
        #expect(diff == expected)
    }
    
    @Test("Add interface if InterfaceSources/ is not empty")
    func addInterface() throws {
      // Given
      let repoURL = try findRepo(named: "test-repo-1")
      let mockFileManager = MockFileManager(copyingRepoAt: repoURL)
      fileManager = mockFileManager
      // Add a test file to /ModuleB/Tests/
        try mockFileManager.write("", to: URL(filePath: "/repo/ModuleB/InterfaceSources/Interface.swift"), atomically: true, encoding: .utf8)
      let before = mockFileManager.files

      // When
      _ = try UpdateDependencies.update(packageURL: URL(filePath: "/repo/Package.swift"), all: true)

      // Then
      let diff = try diffFiles(before: before, after: mockFileManager.files)
      let expected = """
        diff --git a/ModuleB/Module.swift b/ModuleB/Module.swift
        --- a/ModuleB/Module.swift
        +++ b/ModuleB/Module.swift
        @@ -2,4 +2,5 @@ Target.module(
           name: "ModuleB",
           dependencies: [
           "ModuleA",
        -])
        +],
        +  interfaceDependencies: [])
        diff --git a/ModuleB/Package.swift b/ModuleB/Package.swift
        --- a/ModuleB/Package.swift
        +++ b/ModuleB/Package.swift
        @@ -111,6 +111,7 @@ targets.append(
             dependencies: [
               .product(name: "ModuleA", package: "ModuleA")
             ],
        +    interfaceDependencies: [],
             path: "."))
         
         let package = Package(
        @@ -119,7 +120,8 @@ let package = Package(
             .macOS("15.2")
           ],
           products: [
        -    .library(name: "ModuleB", targets: ["ModuleB"])
        +    .library(name: "ModuleB", targets: ["ModuleB"]),
        +    .library(name: "ModuleBInterface", targets: ["ModuleBInterface"]),
           ],
           dependencies: [
             .package(path: "../ModuleA")
        diff --git a/Package.swift b/Package.swift
        --- a/Package.swift
        +++ b/Package.swift
        @@ -120,6 +120,7 @@ targets.append(
             dependencies: [
               "ModuleA"
             ],
        +    interfaceDependencies: [],
             path: "./ModuleB"))
         
         let package = Package(
        """
      #expect(diff == expected)
    }

  /// The resources are located in different locations depending on whether the test is run from `swift test` or from Xcode.
  /// This helper finds the correct path in both cases.
  private func findRepo(named name: String) throws -> URL {
    guard let baseURL = Bundle.module.resourceURL else { throw TestError("Could not find resources") }
    guard
      let enumerator = FileManager.default.enumerator(
        at: baseURL,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: .skipsHiddenFiles)
    else {
      throw TestError("Could not find resources")
    }
    for case let fileURL as URL in enumerator {
      if fileURL.lastPathComponent == name {
        let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
        if resourceValues?.isDirectory == true {
          return fileURL
        }
      }
    }
    throw TestError("Could not find resources")
  }

  private func diffFiles(before: [String: String], after: [String: String]) throws -> String {
    // git diff --no-index dir1 dir2
    let tempDir1 = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir1, withIntermediateDirectories: true)
    let root1 = before.rootPath
    for (filePath, content) in before {
      let relativePath = filePath.hasPrefix(root1) ? String(filePath.dropFirst(root1.count)) : filePath
      let fullPath = tempDir1.appending(path: relativePath).path
      try write(content: content, to: fullPath)
    }
    let tempDir2 = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir2, withIntermediateDirectories: true)
    let root2 = after.rootPath
    for (filePath, content) in after {
      let relativePath = filePath.hasPrefix(root2) ? String(filePath.dropFirst(root2.count)) : filePath
      let fullPath = tempDir2.appending(path: relativePath).path
      try write(content: content, to: fullPath)
    }
    return try executeShellCommand("git diff --no-index \(tempDir1.path) \(tempDir2.path)")
      .replacingOccurrences(of: tempDir1.path, with: "")
      .replacingOccurrences(of: tempDir2.path, with: "")
      .split(separator: "\n")
      .filter { !$0.hasPrefix("index ") }
      .joined(separator: "\n")
  }

  private func write(content: String, to path: String) throws {
    let url = URL(filePath: path)
    let directoryURL = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    try content.write(to: url, atomically: true, encoding: .utf8)
  }

  private func executeShellCommand(_ command: String) throws -> String {
    let process = Process()
    process.launchPath = "/bin/bash" // Or /bin/zsh, depending on your shell
    process.arguments = ["-c", command]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe // Redirect stderr to the same pipe for combined output

    try process.run() // Launch the process

    // Wait until the process finishes
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8) {
      return output.trimmingCharacters(in: .whitespacesAndNewlines)
    } else {
      throw NSError(domain: "ShellCommandError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode output"])
    }
  }

}

typealias FileContents = [String: String]
extension FileContents {
  var rootPath: String {
    var repoPrefix: URL? = nil
    if let key = keys.first {
      repoPrefix = URL(string: key)
    }
    for filePath in keys {
      while !filePath.hasPrefix(repoPrefix?.path ?? ""), repoPrefix?.pathComponents.count ?? 0 > 1 {
        repoPrefix = repoPrefix?.deletingLastPathComponent()
      }
    }
    return repoPrefix?.path ?? "/"
  }
}

// MARK: - TestError

struct TestError: Error {
  let message: String
  init(_ message: String) {
    self.message = message
  }
}

extension MockFileManager {

  func remove(line: String, in file: String) throws {
    guard let content = files[file] else {
      throw TestError("File \(file) not found")
    }
    let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
    let filteredLines = lines.filter {
      $0.trimmingCharacters(in: .whitespaces) != line.trimmingCharacters(in: .whitespaces)
    }
    try write(filteredLines.joined(separator: "\n"), to: URL(filePath: file), atomically: true, encoding: .utf8)
  }
}
