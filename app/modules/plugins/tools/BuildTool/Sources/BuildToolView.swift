// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodePreview
import DLS
import LocalServerServiceInterface
import SwiftUI
import ToolFoundation
import XcodeControllerServiceInterface

// MARK: - BuildTool.Use + DisplayableToolUse

extension BuildTool.Use: DisplayableToolUse {
  public var viewModel: AnyToolUseViewModel {
    AnyToolUseViewModel(ToolUseViewModel(
      buildType: input.for,
      status: status))
  }
}

// MARK: - ToolUseView

struct ToolUseView: View {

  @Bindable var toolUse: ToolUseViewModel

  var body: some View {
    switch toolUse.status {
    case .notStarted:
      EmptyView()
    case .pendingApproval:
      pendingApprovalContent
    case .approvalRejected:
      rejectedContent
    case .running:
      buildingContent
    case .completed(.success(let buildResult)):
      buildResultsContent(buildResult: buildResult)
    case .completed(.failure(let error)):
      failureContent(error: error)
    }
  }

  @State private var isExpanded = false
  @State private var isHovered = false

  @Environment(\.colorScheme) private var colorScheme

  private var foregroundColor: Color {
    if isHovered {
      .primary
    } else {
      colorScheme.toolUseForeground
    }
  }

  @ViewBuilder
  private var pendingApprovalContent: some View {
    HStack {
      Icon(systemName: "hammer")
        .frame(width: 14, height: 14)
        .foregroundColor(foregroundColor)
        .frame(width: 15)
      Text("Waiting for approval: Build")
        .font(.system(.body, design: .monospaced))
        .foregroundColor(foregroundColor)
        .lineLimit(1)
      Spacer(minLength: 0)
    }
  }

  @ViewBuilder
  private var rejectedContent: some View {
    HStack {
      Icon(systemName: "hammer")
        .frame(width: 14, height: 14)
        .foregroundColor(foregroundColor)
        .frame(width: 15)
      Text("Rejected: Build")
        .font(.system(.body, design: .monospaced))
        .foregroundColor(foregroundColor)
        .lineLimit(1)
      Spacer(minLength: 0)
    }
  }

  @ViewBuilder
  private var buildingContent: some View {
    HStack {
      Icon(systemName: "hammer")
        .frame(width: 14, height: 14)
        .foregroundColor(foregroundColor)
        .frame(width: 15)
      Text("Building")
        .font(.system(.body, design: .monospaced))
        .foregroundColor(foregroundColor)
        .lineLimit(1)

      ProgressView()
        .controlSize(.small)
        .frame(width: 12, height: 12)
      Spacer(minLength: 0)
    }
  }

  @ViewBuilder
  private func buildResultsContent(buildResult: BuildTool.Use.Output) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header with expand/collapse
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
          Icon(systemName: "hammer")
            .frame(width: 14, height: 14)
            .foregroundColor(foregroundColor)
            .frame(width: 15)
        }

        if buildResult.isSuccess {
          Text("Build succeeded")
            .font(.system(.body, design: .monospaced))
            .foregroundColor(foregroundColor)
            .lineLimit(1)
          Image(systemName: "checkmark")
            .foregroundColor(colorScheme.addedLineDiffText)
        } else {
          Text("Build failed")
            .font(.system(.body, design: .monospaced))
            .foregroundColor(foregroundColor)
            .lineLimit(1)
          Image(systemName: "xmark")
            .foregroundColor(colorScheme.removedLineDiffText)
        }

        Spacer(minLength: 0)
      }
      .tappableTransparentBackground()
      .onTapGesture { isExpanded.toggle() }
      .acceptClickThrough()
      .onHover { isHovered = $0 }

      // Build messages list (when expanded)
      if isExpanded {
        BuildResultSectionView(
          buildResultSection: buildResult.buildResult,
          isInitiallyExpanded: true,
          foregroundColor: foregroundColor)
          .padding(.leading, 15)
          .padding(.top, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  @ViewBuilder
  private func failureContent(error: Error) -> some View {
    HStack {
      Icon(systemName: "xmark.circle.fill")
        .frame(width: 14, height: 14)
        .foregroundColor(colorScheme.xcodeErrorColor)
        .frame(width: 15)
      Text("Build failed: \(error.localizedDescription)")
        .font(.system(.body, design: .monospaced))
        .foregroundColor(colorScheme.xcodeErrorColor)
        .lineLimit(1)
      Spacer(minLength: 0)
    }
  }

}

// MARK: - BuildResultSectionView

struct BuildResultSectionView: View {
  init(buildResultSection: BuildSection, isInitiallyExpanded: Bool, foregroundColor: Color) {
    self.buildResultSection = buildResultSection
    self.foregroundColor = foregroundColor
    _isExpanded = State(initialValue: isInitiallyExpanded)
  }

  let buildResultSection: BuildSection
  let foregroundColor: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: Constants.hstackSpacing) {
        optionalExpandButton
          .frame(width: Constants.chevronSize, height: Constants.chevronSize)
          .padding(.horizontal, Constants.hstackSpacing)
        icon(for: buildResultSection.maxSeverity)
          .frame(width: Constants.iconSize, height: Constants.iconSize)
        Text(buildResultSection.title)
          .textSelection(.enabled)
          .foregroundColor(foregroundColor)
          .lineLimit(1)
        Text("\(duration) s")
          .foregroundColor(colorScheme.toolUseForeground)
      }
      if isExpanded {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(Array(zip(buildResultSection.messages.indices, buildResultSection.messages)), id: \.0) { index, message in
            HStack(spacing: Constants.hstackSpacing) {
              icon(for: message.severity, displayInfo: false)
                .frame(width: Constants.iconSize, height: Constants.iconSize)
              VStack(alignment: .leading) {
                if let location = message.location {
                  Text("\(location.file.lastPathComponent):\(location.startingLineNumber ?? 0)")
                }
                Text(message.message)
                  .textSelection(.enabled)
                  .foregroundColor(foregroundColor)
                  .lineLimit(1)
              }
            }
            .padding(.leading, Constants.chevronSize + Constants.hstackSpacing * 3)
            .id("message-\(index)")
          }

          ForEach(
            Array(zip(buildResultSection.subSections.indices, buildResultSection.subSections)),
            id: \.0)
          { index, subSection in
            BuildResultSectionView(buildResultSection: subSection, isInitiallyExpanded: false, foregroundColor: foregroundColor)

              .id("section-\(index)")
          }
        }
        .padding(.leading, Constants.indentation)
      }
    }
  }

  private enum Constants {
    static let iconSize: CGFloat = 10
    static let indentation: CGFloat = 8
    static let chevronSize: CGFloat = 10
    static let hstackSpacing: CGFloat = 2
  }

  @State private var isExpanded: Bool

  @Environment(\.colorScheme) private var colorScheme

  private var duration: String {
    let duration = String(format: "%0.1f", buildResultSection.duration)
    if duration == "0.0" {
      return "0.1"
    }
    return duration
  }

  @ViewBuilder
  private var optionalExpandButton: some View {
    if buildResultSection.subSections.isEmpty {
      Rectangle().fill(.clear)
    } else {
      IconButton(action: {
        isExpanded.toggle()
      }, systemName: isExpanded ? "chevron.down" : "chevron.right")
        .foregroundColor(foregroundColor)
    }
  }

  @ViewBuilder
  private func icon(for severity: BuildMessage.Severity, displayInfo: Bool = true) -> some View {
    switch severity {
    case .info:
      if displayInfo {
        Icon(systemName: "checkmark.circle.fill")
          .foregroundColor(colorScheme.xcodeSuccessColor)
      } else {
        Rectangle().fill(.clear)
      }

    case .warning:
      Icon(systemName: "exclamationmark.triangle.fill")
        .foregroundColor(colorScheme.xcodeWarningColor)

    case .error:
      Icon(systemName: "xmark.circle.fill")
        .foregroundColor(colorScheme.xcodeErrorColor)
    }
  }

}
