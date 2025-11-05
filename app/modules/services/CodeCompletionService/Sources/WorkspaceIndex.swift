// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodeCompletionFoundation
import Foundation
import LoggingServiceInterface
import ShellServiceInterface

// MARK: - WorkspaceIndex

// TODO: buffer updates for file change (don't do every char)
// TODO: get tabSize etc, maybe from XcodeExtension?
// TODO: check if URL is a stable key for dictionaries

/// A representation of the files in a workspace.
/// The list of files is kept up to date.
final class WorkspaceIndex: Workspace {
  init(url: URL, root: URL, files: @escaping @Sendable () -> [URL]) {
    self.url = url
    self.root = root
    _files = files
  }

  let root: URL
  let url: URL

  var files: [URL] { _files() }

  private let _files: @Sendable () -> [URL]

}
