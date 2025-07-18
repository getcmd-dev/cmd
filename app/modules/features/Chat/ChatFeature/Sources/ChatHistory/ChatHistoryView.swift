// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import DLS
import SwiftUI

struct ChatHistoryView: View {
  enum Constants {
    static let leadingPadding: CGFloat = 8
  }

  @Bindable var viewModel: ChatHistoryViewModel

  let onBack: @MainActor () -> Void
  let onSelectThread: @MainActor (UUID) -> Void

  var body: some View {
    VStack(spacing: 0) {
      headerView
      threadsList
    }
    .padding(.horizontal, 16)
    .background(colorScheme.primaryBackground)
    .onAppear {
      Task {
        await viewModel.reload()
      }
    }
    .task {
      await viewModel.loadMoreThreadsIfNeeded()
    }
  }

  @Environment(\.colorScheme) private var colorScheme

  @ViewBuilder
  private var headerView: some View {
    HStack {
      IconButton(
        action: onBack,
        systemName: "chevron.left",
        onHoverColor: colorScheme.secondarySystemBackground,
        padding: 6)
        .frame(square: ChatView.Constants.iconSize)
        .padding(4)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 12)
  }

  @ViewBuilder
  private var threadsList: some View {
    ScrollView {
      LazyVStack(spacing: 8) {
        ForEach(viewModel.threadsByDay, id: \.key) { kv in
          VStack(alignment: .leading, spacing: 2) {
            HStack {
              Spacer(minLength: 0)
              Text(dayDisplay(dayDiff: kv.key))
                .font(.caption)
                .foregroundColor(colorScheme.secondaryForeground)
                .id(kv.key)
                .padding(.leading, Constants.leadingPadding)
            }

            ForEach(kv.value) { thread in
              threadRow(thread)
                .onAppear {
                  if thread.id == viewModel.threads.last?.id {
                    Task {
                      await viewModel.loadMoreThreadsIfNeeded()
                    }
                  }
                }
            }
          }
        }

        if viewModel.isLoading {
          ProgressView()
            .padding()
        }
      }
    }
  }

  @ViewBuilder
  private func threadRow(_ thread: ChatHistoryViewModel.ThreadInfo) -> some View {
    HoveredButton(
      action: {
        onSelectThread(thread.id)
      },
      onHoverColor: colorScheme.secondarySystemBackground)
    {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(thread.name)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.primary)
            .lineLimit(1)
        }

        Spacer()
      }
      .padding(.leading, Constants.leadingPadding)
      .padding(.vertical, 5)
    }
    .buttonStyle(PlainButtonStyle())
    .cornerRadius(6)
  }

  private func dayDisplay(dayDiff: Int) -> String {
    switch dayDiff {
    case 0:
      "Today"
    case 1:
      "Yesterday"
    default:
      "\(dayDiff) days ago"
    }
  }
}
