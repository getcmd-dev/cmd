// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import FileSuggestionServiceInterface
import SwiftUI

// MARK: - SearchResultsView

struct SearchResultsView: View {

  init(
    selectedRowIndex: Binding<Int>,
    results: [FileSuggestion],
    didSelect: @escaping (FileSuggestion?) -> Void = { _ in },
    searchInput: Binding<String?> = .constant(nil))
  {
    _selectedRowIndex = selectedRowIndex
    self.results = results
    self.didSelect = didSelect
    _searchInput = searchInput
    _unwrappedSearchInput = Binding(
      get: { searchInput.wrappedValue ?? "" },
      set: {
        if searchInput.wrappedValue != nil {
          searchInput.wrappedValue = $0
        }
      })
  }

  @FocusState var focused: Bool?

  var body: some View {
    VStack(spacing: 0) {
      ScrollViewReader { scrollProxy in
        ScrollView([.vertical]) {
          LazyVStack(spacing: 0) {
            if hasSearchInput {
              SearchInput(
                searchInput: $unwrappedSearchInput,
                results: results,
                didSelect: didSelect,
                selectedRowIndex: $selectedRowIndex)
                .frame(height: Self.searchInputHeight)
            }
            ForEach(Array(zip(results.indices, results)), id: \.1.id) { index, result in
              HStack(alignment: .center, spacing: 0) {
                FileIcon(filePath: result.path)
                  .frame(width: 10, height: 10)

                Text(result.path.lastPathComponent)
                  .foregroundColor(Color.primary)
                  .lineLimit(1)
                  .padding(.horizontal, 4)
                  .layoutPriority(1)

                Spacer(minLength: 0)

                Text(result.displayPath)
                  .foregroundColor(Color.secondary)
                  .font(.system(size: 10))
                  .lineLimit(1)
                  .truncationMode(.head)
                  .layoutPriority(0)
              }
              .padding(.horizontal, 4)
              .frame(height: Self.rowHeight)
              .onHover { hovering in
                if hovering {
                  selectedRowIndex = index
                }
              }
              .onTapGesture {
                didSelect(result)
              }
              .background(index == selectedRowIndex ? Color.gray.opacity(0.2) : Color.clear)
            }
          }
          .scrollTargetLayout()
        }
        .onScrollTargetVisibilityChange(idType: Int.self, threshold: 1) { identifiers in
          entirelyVisibleRowIndexes = identifiers
        }
        .frame(height: height)
        .cornerRadius(0)
        .with(cornerRadius: 6, borderColor: .gray)
        .onChange(of: selectedRowIndex) {
          handleSelectionChanged(using: scrollProxy)
        }
      }
    }
    .background(colorScheme.primaryBackground)
  }

  private static let searchInputHeight: CGFloat = 30

  private static let rowHeight: CGFloat = 24

  @Binding private var searchInput: String?
  @Binding private var unwrappedSearchInput: String

  @State private var entirelyVisibleRowIndexes = [Int]()

  @Environment(\.colorScheme) private var colorScheme
  @Binding private var selectedRowIndex: Int

  private let results: [FileSuggestion]
  private let didSelect: (FileSuggestion?) -> Void

  private var hasSearchInput: Bool {
    searchInput != nil
  }

  private var displayedRowCount: Int {
    min(10, results.count)
  }

  private var height: CGFloat {
    var height = CGFloat(displayedRowCount) * Self.rowHeight
    if hasSearchInput {
      height += Self.searchInputHeight
    }
    return height
  }

  private func handleSelectionChanged(using proxy: ScrollViewProxy) {
    guard
      let firstVisibleIndex = entirelyVisibleRowIndexes.first,
      let lastVisibleIndex = entirelyVisibleRowIndexes.last
    else {
      // it seems that entirelyVisibleRowIndexes is empty on the first layout (which happens everytime the view is updated).
      return
    }
    if selectedRowIndex < firstVisibleIndex {
      proxy.scrollTo(selectedRowIndex, anchor: .top)
    } else if selectedRowIndex > lastVisibleIndex {
      proxy.scrollTo(selectedRowIndex, anchor: .bottom)
    }
  }

}

// MARK: - SearchInput

struct SearchInput: View {

  init(
    searchInput: Binding<String>,
    results: [FileSuggestion],
    didSelect: @escaping (FileSuggestion?) -> Void,
    selectedRowIndex: Binding<Int> = .constant(0))
  {
    _searchInput = searchInput
    self.results = results
    self.didSelect = didSelect
    _selectedRowIndex = selectedRowIndex
  }

  var body: some View {
    TextField(text: $searchInput) {
      Text("Add files")
    }
    .focused($isTextFieldFocused)
    .onAppear {
      isTextFieldFocused = true
    }
    .onKeyPress(.downArrow) {
      selectedRowIndex = min(selectedRowIndex + 1, results.count - 1)
      return .handled
    }
    .onKeyPress(.upArrow) {
      selectedRowIndex = max(selectedRowIndex - 1, 0)
      return .handled
    }

    .onKeyPress(.escape) {
      didSelect(nil)
      return .handled
    }
    .onKeyPress(.return) {
      didSelect(results[selectedRowIndex])
      return .handled
    }
    .textFieldStyle(PlainTextFieldStyle())
    .padding(.horizontal, 8)
  }

  @Binding private var searchInput: String
  @Binding private var selectedRowIndex: Int
  @FocusState private var isTextFieldFocused: Bool

  private let results: [FileSuggestion]
  private let didSelect: (FileSuggestion?) -> Void

}
