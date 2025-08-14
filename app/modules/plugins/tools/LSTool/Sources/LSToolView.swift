// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import LocalServerServiceInterface
import SwiftUI
import ToolFoundation

// MARK: - ToolUseView

struct ToolUseView: View {
  @Bindable private var viewModel: ToolUseViewModel

  init(viewModel: ToolUseViewModel) {
    self.viewModel = viewModel
  }

  var body: some View {
    ToolUseDetailView(status: viewModel.status, directoryPath: viewModel.directoryPath)
  }
}

// MARK: - ToolUseDetailView

struct ToolUseDetailView: View {

  let status: ToolUseExecutionStatus<LSTool.Use.Output>
  let directoryPath: URL

  var body: some View {
    switch status {
    case .notStarted:
      EmptyView()
    case .pendingApproval:
      pendingApprovalView
    case .approvalRejected:
      rejectedView
    case .running:
      runningView
    case .completed(.success(let files)):
      successView(files: files)
    case .completed(.failure(let error)):
      errorView(error: error)
    }
  }

  @State private var isExpanded = false
  @State private var isHovered = false

  @Environment(\.colorScheme) private var colorScheme

  @ViewBuilder
  private var pendingApprovalView: some View {
    HStack {
      Icon(systemName: "folder")
        .frame(width: 14, height: 14)
        .foregroundColor(foregroundColor)
      Text("Waiting for approval: List \(directoryPath.lastPathComponent)")
        .foregroundColor(foregroundColor)
    }
  }

  @ViewBuilder
  private var rejectedView: some View {
    HStack {
      Icon(systemName: "folder")
        .frame(width: 14, height: 14)
        .foregroundColor(foregroundColor)
      Text("Rejected: List \(directoryPath.lastPathComponent)")
        .foregroundColor(foregroundColor)
    }
  }

  @ViewBuilder
  private var runningView: some View {
    HStack {
      Icon(systemName: "folder")
        .frame(width: 14, height: 14)
        .foregroundColor(foregroundColor)
      Text("Listing \(directoryPath.lastPathComponent)...")
        .foregroundColor(foregroundColor)
    }
  }

  private var foregroundColor: Color {
    if isHovered {
      .primary
    } else {
      colorScheme.toolUseForeground
    }
  }

  @ViewBuilder
  private func successView(files: LSTool.Use.Output) -> some View {
    VStack(alignment: .leading) {
      HStack {
        if isExpanded {
          Icon(systemName: "chevron.down")
            .frame(width: 14, height: 14)
            .foregroundColor(foregroundColor)
            .frame(width: 15)
        } else if isHovered {
          Icon(systemName: "chevron.right")
            .frame(width: 14, height: 14)
            .foregroundColor(foregroundColor)
            .frame(width: 15)
        } else {
          Icon(systemName: "folder")
            .frame(width: 14, height: 14)
            .foregroundColor(foregroundColor)
            .frame(width: 15)
        }
        Text("Listed \(files.files.count) files in \(directoryPath.lastPathComponent)")
          .foregroundColor(foregroundColor)
      }
      .tappableTransparentBackground()
      .onTapGesture { isExpanded.toggle() }
      .acceptClickThrough()
      if isExpanded {
        HStack {
          Spacer().frame(width: 15)
          LazyVStack {
            ForEach(files.files) { file in
              HStack(spacing: 3) {
                if file.attr?.hasPrefix("d") == true {
                  Icon(systemName: "folder")
                    .foregroundColor(foregroundColor)
                    .frame(width: 12, height: 12)
                } else {
                  FileIcon(filePath: URL(fileURLWithPath: file.path))
                    .frame(width: 12, height: 12)
                }
                Text(URL(fileURLWithPath: file.path).lastPathComponent)
                  .foregroundColor(foregroundColor)
                Spacer()
                if let size = file.size, file.attr?.starts(with: "d") == false {
                  Text(size)
                    .foregroundColor(foregroundColor)
                }
              }
              .padding(.vertical, 2)
            }
          }
        }
      }
    }.onHover { isHovered = $0 }
  }

  @ViewBuilder
  private func errorView(error: Error) -> some View {
    HStack {
      Icon(systemName: "folder")
        .frame(width: 14, height: 14)
        .foregroundColor(foregroundColor)
      Text("Listing \(directoryPath.lastPathComponent) failed: \(error.localizedDescription)")
        .foregroundColor(foregroundColor)
    }
  }

}

// MARK: - LSTool.Use.Output.File + Identifiable

extension LSTool.Use.Output.File: Identifiable {
  public var id: String { path }
}
