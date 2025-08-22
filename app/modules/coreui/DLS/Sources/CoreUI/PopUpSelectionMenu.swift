// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - MenuItem

public protocol MenuItem: Identifiable, Equatable { }

// MARK: - PopUpSelectionMenu

public struct PopUpSelectionMenu<Item: MenuItem, Content: View>: View {
  /// A view that displays a list of items as a pop-up menu and allows the user to select one.
  /// - Parameters:
  ///   - selectedItem: The item that is currently selected.
  ///   - availableItems: The list of items to display in the menu.
  ///   - searchKey: A function that returns the search key for an item. If nil, search is disabled.
  ///   - isExpanded: When provided, a binding that describes whether the popup is expanded.
  ///   - viewBuilder: Returns a view to display an item.
  public init(
    selectedItem: Binding<Item>,
    availableItems: [Item],
    searchKey: ((Item) -> String)? = nil,
    isExpanded: Binding<Bool>? = nil,
    @ViewBuilder viewBuilder: @escaping (Item) -> Content)
  {
    _selectedItem = .init(
      get: { selectedItem.wrappedValue },
      set: { newValue in
        if let newValue {
          selectedItem.wrappedValue = newValue
        }
      })
    self.availableItems = availableItems
    self.searchKey = searchKey
    emptySelectionText = "Select an item"
    self.viewBuilder = viewBuilder

    _isExpandedBinding = .init(
      get: { isExpanded?.wrappedValue },
      set: { newValue in
        if let newValue {
          isExpanded?.wrappedValue = newValue
        }
      })
  }

  /// A view that displays a list of items as a pop-up menu and allows the user to select one.
  /// - Parameters:
  ///   - selectedItem: The item that is currently selected.
  ///   - availableItems: The list of items to display in the menu.
  ///   - searchKey: A function that returns the search key for an item. If nil, search is disabled.
  ///   - emptySelectionText: The text to display when no item is selected.
  ///   - isExpanded: When provided, a binding that describes whether the popup is expanded.
  ///   - viewBuilder: Returns a view to display an item.
  public init(
    selectedItem: Binding<Item?>,
    availableItems: [Item],
    searchKey: ((Item) -> String)? = nil,
    emptySelectionText: String,
    isExpanded: Binding<Bool>? = nil,
    @ViewBuilder viewBuilder: @escaping (Item) -> Content)
  {
    _selectedItem = selectedItem
    self.availableItems = availableItems
    self.searchKey = searchKey
    self.emptySelectionText = emptySelectionText
    self.viewBuilder = viewBuilder

    _isExpandedBinding = .init(
      get: { isExpanded?.wrappedValue },
      set: { newValue in
        if let newValue {
          isExpanded?.wrappedValue = newValue
        }
      })
  }

  public var body: some View {
    Button {
      isExpanded.toggle()
    } label: {
      HStack(spacing: 4) {
        if let selectedItem {
          viewBuilder(selectedItem)
        } else {
          Text(emptySelectionText)
        }
        Icon(systemName: isExpanded ? "chevron.down" : "chevron.up")
          .frame(width: 6, height: 6)
      }.tappableTransparentBackground()
    }
    .buttonStyle(.plain)
    .overlay(alignment: .bottomLeading) {
      if isExpanded {
        VStack(spacing: 0) {
          if searchKey != nil {
            // Search field
            TextField("Search...", text: $searchText)
              .textFieldStyle(.plain)
              .padding(8)

            Divider()
          }

          // Items list
          VStack(spacing: 0) {
            ForEach(filteredItems) { item in
              Button {
                selectedItem = item
                isExpanded = false
                searchText = ""
              } label: {
                HStack {
                  viewBuilder(item)
                  Spacer()
                  if item == selectedItem {
                    Icon(systemName: "checkmark")
                      .frame(width: 8, height: 8)
                  }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                  colorScheme.secondarySystemBackground
                    .opacity(item == selectedItem ? 1 : 0.001))
              }
              .buttonStyle(.plain)

              if item != filteredItems.last {
                Divider()
              }
            }
          }
        }
        .cornerRadius(6)
        .background(
          RoundedRectangle(cornerRadius: 6)
            .fill(colorScheme.primaryBackground)
            .overlay(
              RoundedRectangle(cornerRadius: 6)
                .stroke(colorScheme.textAreaBorderColor, lineWidth: 1)))
        .offset(y: -30)
        .fixedSize(horizontal: true, vertical: false)
        .onOutsideTap {
          isExpanded = false
        }
      }
    }
  }

  @Binding private var selectedItem: Item?

  @Environment(\.colorScheme) private var colorScheme

  @State private var searchText = ""
  @Binding private var isExpandedBinding: Bool?
  @State private var isExpandedDefaultState = false

  private let availableItems: [Item]
  private let searchKey: ((Item) -> String)?
  private let emptySelectionText: String
  private let viewBuilder: (Item) -> Content

  private var isExpanded: Bool {
    get {
      isExpandedBinding ?? isExpandedDefaultState
    }
    nonmutating set {
      isExpandedBinding = newValue
      isExpandedDefaultState = newValue
    }
  }

  private var filteredItems: [Item] {
    if searchText.isEmpty {
      return availableItems
    }
    return availableItems.filter { searchKey?($0).localizedCaseInsensitiveContains(searchText) == true }
  }

}
