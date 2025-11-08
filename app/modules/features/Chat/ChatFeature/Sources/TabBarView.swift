// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import SwiftUI

// MARK: - TabBarView

/// A tab bar view that displays multiple chat tabs with support for selection, closing, and adding new tabs.
///
/// The tab bar features:
/// - Scrollable tabs when there are too many to fit
/// - Individual tabs with hover-to-show close buttons
/// - A "+" button to create new tabs
/// - Minimum and flexible width for each tab
struct TabBarView: View {

  init(
    tabs: [ChatThreadViewModel],
    currentTabIndex: Int,
    onSelectTab: @escaping (Int) -> Void,
    onCloseTab: @escaping (Int) -> Void,
    onAddTab: @escaping () -> Void)
  {
    self.tabs = tabs
    self.currentTabIndex = currentTabIndex
    self.onSelectTab = onSelectTab
    self.onCloseTab = onCloseTab
    self.onAddTab = onAddTab
  }

  enum Constants {
    static let iconSize: CGFloat = 22
    static let tabBarHeight: CGFloat = 36
    static let tabHorizontalSpacing: CGFloat = 4
  }

  var body: some View {
    HStack(spacing: 0) {
      ScrollViewReader { proxy in
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: Constants.tabHorizontalSpacing) {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
              TabItemView(
                title: tab.name ?? "New Chat",
                isSelected: index == currentTabIndex,
                hasUnreadCompletion: tab.hasUnreadCompletion,
                isStreaming: tab.isStreamingResponse,
                onSelect: {
                  onSelectTab(index)
                },
                onClose: {
                  onCloseTab(index)
                })
                .id(tab.id)
            }
          }
        }
        .onChange(of: tabs.count) { _, newCount in
          // Scroll to the last tab when a new one is added
          if newCount > 0, let lastTab = tabs.last {
            withAnimation {
              proxy.scrollTo(lastTab.id, anchor: .trailing)
            }
          }
        }
      }

      // Add tab button
      IconButton(
        action: onAddTab,
        systemName: "plus",
        onHoverColor: colorScheme.secondarySystemBackground,
        padding: 4)
        .frame(square: Constants.iconSize)
        .padding(4)
    }
    .frame(height: Constants.tabBarHeight)
    .background(colorScheme.primaryBackground)
    .padding(.horizontal, Constants.tabHorizontalSpacing)
  }

  @Environment(\.colorScheme) private var colorScheme

  private let tabs: [ChatThreadViewModel]
  private let currentTabIndex: Int
  private let onSelectTab: (Int) -> Void
  private let onCloseTab: (Int) -> Void
  private let onAddTab: () -> Void

}

// MARK: - TabItemView

/// A single tab item in the tab bar.
private struct TabItemView: View {

  init(
    title: String,
    isSelected: Bool,
    hasUnreadCompletion: Bool,
    isStreaming: Bool,
    onSelect: @escaping () -> Void,
    onClose: @escaping () -> Void)
  {
    self.title = title
    self.isSelected = isSelected
    self.hasUnreadCompletion = hasUnreadCompletion
    self.isStreaming = isStreaming
    self.onSelect = onSelect
    self.onClose = onClose
  }

  enum Constants {
    static let minTabWidth: CGFloat = 100
    static let fontSize: CGFloat = 12
    static let height: CGFloat = 20
    static var textVerticalPadding: CGFloat { (height - fontSize) / 2.0 }
    static let closeButtonMargin: CGFloat = 2
    static var closeButtonSize: CGFloat { height - closeButtonMargin }
  }

  var body: some View {
    HoveredButton(
      action: onSelect,
      onHoverColor: .clear,
      backgroundColor: .clear,
      padding: 0,
      cornerRadius: 0)
    { isHovered in
      ZStack(alignment: .trailing) {
        // Tab title - always takes up the full width
        Text(title)
          .font(.system(size: Constants.fontSize))
          .foregroundColor(isSelected ? .primary : .secondary)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 8)
          .padding(.vertical, Constants.textVerticalPadding)
          .readingSize { size in textSize = size }
        // Close button - overlays on the right side when hovering
        if hasOverlayButton(isHovered: isHovered) {
          ZStack(alignment: .trailing) {
            // Gradient fade to hide text under the button
            LinearGradient(
              colors: [
                backgroundColor(isHovered: isHovered).opacity(0),
                backgroundColor(isHovered: isHovered),
                backgroundColor(isHovered: isHovered),
              ],
              startPoint: .leading,
              endPoint: .trailing)
              .frame(width: 40, height: Constants.height)

            overlayButton(isHovered: isHovered)
              .padding(.trailing, Constants.closeButtonMargin)
          }
        }
      }
      .fixedSize(horizontal: true, vertical: false)
      .frame(minWidth: min(Constants.minTabWidth, textSize?.width ?? 0))
      .background(backgroundColor(isHovered: isHovered))
      .cornerRadius(6)
    }
    .buttonStyle(.plain)
  }

  @State private var textSize: CGSize?

  @Environment(\.colorScheme) private var colorScheme

  private let title: String
  private let isSelected: Bool
  private let hasUnreadCompletion: Bool
  private let isStreaming: Bool
  private let onSelect: () -> Void
  private let onClose: () -> Void

  private func backgroundColor(isHovered: Bool) -> Color {
    if isSelected {
      colorScheme.secondarySystemBackground
    } else if isHovered {
      colorScheme.tertiarySystemBackground
    } else {
      colorScheme.primaryBackground
    }
  }

  private func hasOverlayButton(isHovered: Bool) -> Bool {
    isHovered || hasUnreadCompletion || isStreaming
  }

  @ViewBuilder
  private func overlayButton(isHovered: Bool) -> some View {
    if isHovered {
      IconButton(
        action: onClose,
        systemName: "xmark",
        onHoverColor: colorScheme.tertiarySystemBackground,
        padding: 4)
        .frame(square: Constants.closeButtonSize)
    } else if hasUnreadCompletion {
      IconButton(
        action: onClose,
        systemName: "checkmark",
        onHoverColor: colorScheme.tertiarySystemBackground,
        padding: 4)
        .foregroundColor(colorScheme.greenSuccess)
        .frame(square: Constants.closeButtonSize)
    } else if isStreaming {
      CMDLogoDrawingAnimation(size: Constants.closeButtonSize)
    } else {
      EmptyView()
    }
  }

}
