// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import Combine
import ConcurrencyFoundation
import Foundation
import LoggingServiceInterface
import ShellServiceInterface
import XCLogParser
import XcodeControllerServiceInterface
import XcodeObserverServiceInterface

extension DefaultXcodeController {

  @MainActor
  public func build(project: URL, buildType: BuildType) async throws -> BuildSection {
    let buildLogsDirectory = buildLogsDirectory(for: project)
    let existingBuildLogs = try buildLogFiles(in: buildLogsDirectory)
    try await Self.triggerBuildAction(
      project: project,
      buildType: buildType,
      xcodeObserver: xcodeObserver,
      shellService: shellService)
    let newBuildLog = try await waitForNewBuildLog(in: buildLogsDirectory, existingLogs: existingBuildLogs)

    return newBuildLog.mainSection.mapped
  }

  /// The path to the Derived Data folder.
  private var derivedDataPath: URL {
    let defaultPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
      "Library/Developer/Xcode/DerivedData",
      isDirectory: true)

    guard let xcodeOptions = UserDefaults.standard.persistentDomain(forName: "com.apple.dt.Xcode") else {
      return defaultPath
    }
    guard let customLocation = xcodeOptions["IDECustomDerivedDataLocation"] as? String else {
      return defaultPath
    }
    return URL(fileURLWithPath: customLocation)
  }

  /// Using AX, trigger a build in Xcode.
  @MainActor
  private static func triggerBuildAction(
    project _: URL,
    buildType: BuildType,
    xcodeObserver: XcodeObserver,
    shellService: ShellService)
    async throws
  {
    guard let xcodeApp = await getXcode(xcodeObserver: xcodeObserver, shellService: shellService) else {
      defaultLogger.error("Could not find running Xcode")
      throw AXError.cannotComplete
    }

    if !xcodeApp.activate() {
      defaultLogger.error("Xcode not activated.")
      try? activateXcodeWithAppleScript()
    }

    let appElement = AXUIElementCreateApplication(xcodeApp.processIdentifier)

    guard let menuBar = appElement.menuBar else {
      defaultLogger.error("Could not find menu bar")
      throw AXError.cannotComplete
    }

    let menuIdentifier = buildType == .run ? "buildForRunActiveRunContext:" : "buildForTestActiveRunContext:"

    guard
      let menuItem = menuBar
        .firstChild(where: { el, _ in
          el.identifier == menuIdentifier ? .stopSearching : .continueSearching
        })
    else {
      defaultLogger.error("Could not find build menu")
      throw AXError.cannotComplete
    }

    if AXUIElementPerformAction(menuItem, kAXPressAction as CFString) == .success {
      defaultLogger.log("Clicked the menu item")
    } else {
      defaultLogger.error("Failed to click menu item.")
      throw AXError.cannotComplete
    }

    NSApplication.shared.activate()
  }

  /// Monitor the content of derived data for the given project until a new build log is created.
  private func waitForNewBuildLog(in buildLogsDirectory: URL?, existingLogs: [URL]) async throws -> IDEActivityLog {
    let existingLogs = Set<URL>(existingLogs)
    let (future, continuation) = Future<IDEActivityLog, Error>.make()
    Task {
      do {
        while true {
          let buildLogs = try buildLogFiles(in: buildLogsDirectory)
          if let newBuildLog = buildLogs.first(where: { !existingLogs.contains($0) }) {
            // The new build log is visible on file. However if might not yet be fully written.
            // Use `lsof` to wait for all file handles to be closed.
            while true {
              let lsof = try await shellService.run("/usr/sbin/lsof \(newBuildLog.path)")
              if lsof.stdout?.contains(newBuildLog.path) == true {
                try await Task.sleep(nanoseconds: 10_000_000) // Sleep for 0.01 second
              } else {
                break
              }
            }
            try continuation(.success(ActivityParser().parseActivityLogInURL(
              newBuildLog,
              redacted: false,
              withoutBuildSpecificInformation: false)))
            break
          }
          try await Task.sleep(nanoseconds: 10_000_000) // Sleep for 0.01 second
        }
      } catch {
        continuation(.failure(error))
      }
    }
    return try await future.value
  }

  /// List all the build logs in the given directory.
  private func buildLogFiles(in directory: URL?) throws -> [URL] {
    guard let directory, fileManager.fileExists(atPath: directory.path) else {
      return []
    }
    return try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey])
      .filter { try $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true }
      .filter { $0.pathExtension == "xcactivitylog" }
      .map(\.standardizedFileURL)
  }

  /// The existing directory where Xcode writes derived data (eg build outputs etc) for the given project.
  private func buildLogsDirectory(for project: URL) -> URL? {
    do {
      return try fileManager.contentsOfDirectory(at: derivedDataPath, includingPropertiesForKeys: [.isDirectoryKey])
        .filter { url in
          try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        }
        .filter { url in
          let plistPath = url.appendingPathComponent("info.plist")
          guard fileManager.fileExists(atPath: plistPath.path) else { return false }
          let plistContent = try fileManager.read(contentsOf: plistPath)
          return plistContent.contains(project.path)
        }
        .first?.appendingPathComponent("Logs/Build")
    } catch {
      defaultLogger.error("Error findind build directory for \(project.path):", error)
    }
    return nil
  }

}

// MARK: - IDEActivityLog + @retroactive @unchecked Sendable

extension IDEActivityLog: @retroactive @unchecked Sendable { }

extension IDEActivityLogSection {
  var mapped: BuildSection {
    BuildSection(
      title: title,
      messages: messages.map { message in
        BuildMessage(
          message: message.title,
          severity: BuildMessage.Severity(rawValue: message.severity) ?? .info,
          location: message.location.mapped)
      },
      // Xcode also doesn't show cached results in its UI.
      subSections: subSections.filter { !$0.wasFetchedFromCache }.map(\.mapped),
      duration: timeStoppedRecording - timeStartedRecording)
  }
}

extension DVTDocumentLocation {
  var mapped: BuildMessage.Location? {
    if let file = URL(string: documentURLString) {
      let textLocation = self as? DVTTextDocumentLocation
      return BuildMessage.Location(
        file: file,
        startingLineNumber: (textLocation?.startingLineNumber).map { Int($0) },
        startingColumnNumber: (textLocation?.startingColumnNumber).map { Int($0) },
        endingLineNumber: (textLocation?.endingLineNumber).map { Int($0) },
        endingColumnNumber: (textLocation?.endingColumnNumber).map { Int($0) })
    } else {
      return nil
    }
  }
}
