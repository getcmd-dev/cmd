// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import ArgumentParser
import Foundation
import SwiftModule
import SwiftParser

// MARK: - SyncDependencies

@main
struct SyncDependencies: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "syncDependencies",
    abstract: "Sync package dependencies between source and target paths",
    version: "1.0.0",
    subcommands: [SyncCommand.self, FocusCommand.self])
}

// MARK: - SyncCommand

struct SyncCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sync",
    abstract: "Sync package dependencies from source to target")

  @Option(name: [.short, .long], help: "The path to the root package file to sync")
  var path: String
  @Flag(name: [.short, .long], help: "Also update local package files for each module")
  var all = false

  func run() throws {
    let packageURL = URL(fileURLWithPath: path).canonicalURL
    _ = try UpdateDependencies.update(packageURL: packageURL, all: all)
  }
}

// MARK: - FocusCommand

struct FocusCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "focus",
    abstract: "Create a Package.swift focussed on the specified packages and their dependencies")

  @Option(name: [.short, .long], help: "The path to the root package file")
  var path: String
  @Option(name: [.short, .long], help: "The module to focus on")
  var module = ""
  @Flag(name: [.short, .long], help: "List available dependencies")
  var list = false

  func run() throws {
    let packageURL = URL(fileURLWithPath: path).canonicalURL

    if list {
      let modulesInfo = try UpdateDependencies.update(packageURL: packageURL, all: false)
      print("\(modulesInfo.keys.joined(separator: "\n"))\n")
      return
    }
    guard
      let module = try UpdateDependencies.update(packageURL: packageURL, all: true)[module]
    else {
      FocusCommand.exit(withError: NSError(
        domain: "SyncDependenciesError",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not find module \(module)"]))
    }

    print(module.moduleDir.canonicalURL.appending(path: "Package.swift").path + "\n")
  }
}
