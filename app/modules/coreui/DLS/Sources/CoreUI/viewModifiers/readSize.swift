// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - ViewSizeReader

/// A view that reads the size of its content and reports it via a binding.
public struct ViewSizeReader<Content: View>: View {

  public init(
    content: Content,
    size: Binding<CGSize>)
  {
    self.content = content
    _size = size
  }

  public var body: some View {
    Rectangle()
      .frame(width: 0, height: 0)
      .overlay {
        content
          .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
          } action: { newValue in
            size = newValue
          }
          .hidden()
      }
  }

  @Binding private var size: CGSize

  private let content: Content
}

extension View {
  /// Reads the size of this view and reports it via a binding.
  public func readSize(_ size: Binding<CGSize>) -> some View {
    ViewSizeReader(content: self, size: size)
  }

  /// Reads the size of this view and reports it via a callback.
  public func readSize(_ read: @escaping @MainActor (CGSize) -> Void) -> some View {
    ViewSizeReader(content: self, size: Binding(
      get: { .zero },
      set: { newValue in read(newValue) }))
  }

  /// Reads the size of this view and reports it via a closure. Also display the view.
  public func readingSize(_ read: @escaping @MainActor (CGSize) -> Void) -> some View {
    onGeometryChange(for: CGSize.self) { proxy in
      proxy.size
    } action: { size in
      read(size)
    }
  }

  /// Reads the size of this view and reports it via a binding. Also display the view.
  public func readingSize(_ size: Binding<CGSize>) -> some View {
    onGeometryChange(for: CGSize.self) { proxy in
      proxy.size
    } action: { newSize in
      size.wrappedValue = newSize
    }
  }
}

#Preview {
  struct PreviewView: View {
    @State private var size = CGSize.zero

    var body: some View {
      VStack {
        Text("Hello, World!")
          .readSize($size)
        Text("Size: \(Int(size.width))x\(Int(size.height))")
      }
      .padding()
    }
  }

  return PreviewView()
}
