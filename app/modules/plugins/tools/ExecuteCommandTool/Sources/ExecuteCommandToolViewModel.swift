// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

//
//  ExecuteCommandToolViewModel.swift
//  Packages
//
//  Created by Guigui on 8/18/25.
//
@preconcurrency import Combine
import ConcurrencyFoundation
import Foundation
import Observation
import SwiftUI
import ToolFoundation

// MARK: - ToolUseViewModel

@Observable
@MainActor
final class ToolUseViewModel {

  init(
    command: String,
    status: ExecuteCommandTool.Use.Status,
    stdout: Future<BroadcastedStream<Data>, Never>,
    stderr: Future<BroadcastedStream<Data>, Never>,
    kill: @escaping () async -> Void)
  {
    self.command = command
    self.status = status.value
    self.kill = kill
    Task { [weak self] in
      for await status in status.futureUpdates {
        self?.status = status
      }
    }
    Task { [weak self] in
      let stdoutStream = await stdout.value
      for await data in stdoutStream {
        guard let self else { return }
        stdData += data
        std = String(data: stdData, encoding: .utf8)
      }
    }
    Task { [weak self] in
      let stderrStream = await stderr.value
      for await data in stderrStream {
        guard let self else { return }
        stdData += data
        std = String(data: stdData, encoding: .utf8)
      }
    }
  }

  let command: String
  var status: ToolUseExecutionStatus<ExecuteCommandTool.Use.Output>
  var std: String?
  var stdData = Data()
  let kill: () async -> Void
}

// MARK: ViewRepresentable, StreamRepresentable

extension ToolUseViewModel: ViewRepresentable, StreamRepresentable {
  @MainActor
  var body: AnyView { AnyView(ToolUseView(toolUse: self)) }

  @MainActor
  var streamRepresentation: String? {
    guard case .completed(let result) = status else { return nil }
    switch result {
    case .success(let output):
      return """
        ⏺ Bash(\(command))
          ⎿ Exit code: \(output.exitCode)


        """

    case .failure(let error):
      return """
        ⏺ Bash(\(command))
          ⎿ Failed: \(error.localizedDescription.trimmed(toNotExceed: 300))


        """
    }
  }
}
