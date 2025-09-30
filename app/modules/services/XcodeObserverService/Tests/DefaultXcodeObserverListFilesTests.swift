// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ConcurrencyFoundation
import Foundation
import FoundationInterfaces
import LoggingServiceInterface
import PermissionsServiceInterface
import SettingsServiceInterface
import ShellServiceInterface
import SwiftTesting
import Testing
import XcodeObserverServiceInterface
@testable import XcodeObserverService

// MARK: - ClassForBundle

class ClassForBundle { }

// MARK: - DefaultXcodeObserverListFilesTests

struct DefaultXcodeObserverListFilesTests {

  @Test("xcodeproject") @MainActor
  func testReadingXcodeProj() async throws {
    let fileManager = try MockFileManager(copyingFrom: URL(fileURLWithPath: Bundle.module.bundlePath))
    let sut = DefaultXcodeObserver(
      fileManager: fileManager)

    let workspacePath = path(for: "TestXcodeProjParsing/TestXcodeProjParsing.xcodeproj")
    let (files, workspaceType) = try await sut.listFiles(in: workspacePath)
    #expect(workspaceType == .xcodeProject)
    let rootDir = workspacePath.deletingLastPathComponent()
    let displayPaths = files.map { $0.pathRelative(to: rootDir) }.sorted()
    #expect(displayPaths == [
      "TestXcodeProjParsing.xcodeproj/project.pbxproj",
      "TestXcodeProjParsing.xcodeproj/project.xcworkspace/contents.xcworkspacedata",
      "TestXcodeProjParsing/Assets.xcassets/AccentColor.colorset/Contents.json",
      "TestXcodeProjParsing/Assets.xcassets/AppIcon.appiconset/Contents.json",
      "TestXcodeProjParsing/Assets.xcassets/Contents.json",
      "TestXcodeProjParsing/Config.xcconfig",
      "TestXcodeProjParsing/ContentView.swift",
      "TestXcodeProjParsing/Info.plist",
      "TestXcodeProjParsing/Preview Content/Preview Assets.xcassets/Contents.json",
      "TestXcodeProjParsing/TestXcodeProjParsing.entitlements",
      "TestXcodeProjParsing/TestXcodeProjParsingApp.swift",
      "TestXcodeProjParsingTests.xctest",
      "TestXcodeProjParsingTests/TestXcodeProjParsingTests.swift",
      "TestXcodeProjParsingUITests/TestXcodeProjParsingUITests.swift",
      "TestXcodeProjParsingUITests/TestXcodeProjParsingUITestsLaunchTests.swift",
    ])
  }

  @Test("SPM") @MainActor
  func testSwiftPackage() async throws {
    let fileManager = try MockFileManager(copyingFrom: URL(fileURLWithPath: Bundle.module.bundlePath))
    let shellService = MockShellService()
    shellService.onRun = { command, cwd, _, _, _ in
      #expect(command == "swift package describe --type json")
      #expect(cwd?.hasSuffix("/SPM") == true)
      return CommandExecutionResult(exitCode: 0, stdout: spmPackageDescription)
    }
    let sut = DefaultXcodeObserver(
      fileManager: fileManager,
      shellService: shellService)

    let workspacePath = path(for: "SPM")
    let (files, workspaceType) = try await sut.listFiles(in: workspacePath)
    #expect(workspaceType == .directory)
    let displayPaths = files.map { $0.pathRelative(to: workspacePath) }.sorted()
    #expect(displayPaths == [
      "Package.swift",
      "Sources/TestSPM/TestSPM.swift",
      "Tests/TestSPMTests/TestSPMTests.swift",
    ])
  }

  @Test("directory") @MainActor
  func testFilesFromDirectory() async throws {
    // Note: ideally we would entirely mock the file manager. But the code relies on URL's resourceValues which cannot be mocked
    // (`URLResourceValues` cannot be initialized with specific properties).
    let fileManager = try MockFileManager(copyingFrom: URL(fileURLWithPath: Bundle.module.bundlePath))
    let workspacePath = path(for: "directory")

    let sut = DefaultXcodeObserver(
      fileManager: fileManager)
    let (files, workspaceType) = try await sut.listFiles(in: workspacePath)
    #expect(workspaceType == .directory)
    let displayPaths = files.map { $0.pathRelative(to: workspacePath) }.sorted()
    #expect(displayPaths == [
      "subdirectory/test.txt",
    ])
  }

  private let spmPackageDescription = """
    Warning: some SPM warning that is not JSON...
    {
      "dependencies" : [

      ],
      "manifest_display_name" : "TestSPM",
      "name" : "TestSPM",
      "platforms" : [

      ],
      "products" : [
        {
          "name" : "TestSPM",
          "targets" : [
            "TestSPM"
          ],
          "type" : {
            "library" : [
              "automatic"
            ]
          }
        }
      ],
      "targets" : [
        {
          "c99name" : "TestSPMTests",
          "module_type" : "SwiftTarget",
          "name" : "TestSPMTests",
          "path" : "Tests/TestSPMTests",
          "sources" : [
            "TestSPMTests.swift"
          ],
          "target_dependencies" : [
            "TestSPM"
          ],
          "type" : "test"
        },
        {
          "c99name" : "TestSPM",
          "module_type" : "SwiftTarget",
          "name" : "TestSPM",
          "path" : "Sources/TestSPM",
          "product_memberships" : [
            "TestSPM"
          ],
          "sources" : [
            "TestSPM.swift"
          ],
          "type" : "library"
        }
      ],
      "tools_version" : "6.0"
    }
    """

  private func path(for resource: String) -> URL {
    let bundlePath = URL(fileURLWithPath: Bundle.module.bundlePath)

    if FileManager.default.fileExists(atPath: bundlePath.appendingPathComponent("Contents/Resources/resources/").path) {
      // When running from Xcode, the resources are in the Contents/Resources/Resources/ directory
      return bundlePath.appendingPathComponent("Contents/Resources/resources").appendingPathComponent(resource)
    } else {
      // When running from SPM (CLI), the resources are in the Resources/ directory
      return bundlePath.appendingPathComponent("resources").appendingPathComponent(resource)
    }
  }

}

extension DefaultXcodeObserver {
  @MainActor
  convenience init(
    fileManager: MockFileManager = MockFileManager(),
    shellService: MockShellService = MockShellService())
  {
    let permissionsService = MockPermissionsService()
    let settingsService = MockSettingsService()
    self.init(
      permissionsService: permissionsService,
      fileManager: fileManager as FileManagerI,
      settingsService: settingsService,
      shellService: shellService)
  }

}

extension MockFileManager {
  convenience init(copyingFrom path: URL) throws {
    var files = [String: String]()
    var directories = [String]()

    if
      let enumerator = FileManager.default.enumerator(
        at: path,
        includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey])
    {
      for case let fileURL as URL in enumerator {
        do {
          let fileAttributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
          if fileAttributes.isRegularFile == true {
            files[fileURL.path] = try FileManager.default.read(contentsOf: fileURL, encoding: .utf8)
          } else if fileAttributes.isDirectory == true {
            directories.append(fileURL.path)
          } else {
            print("Unknown file type: \(fileURL)")
          }
        } catch { }
      }
    }

    self.init(files: files, directories: directories)
  }
}
