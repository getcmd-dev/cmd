// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import DLS
import SwiftUI

struct InlineChatView: View {
  let viewModel: InlineChatsViewModel

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .topLeading) {
        if let chat = viewModel.inlineChat {
          Text("Inline Chat Feature Coming Soon!")
            .font(.headline)
            .padding()
            .border(.green)
            .readingSize { contentSize in
              self.contentSize = contentSize
            }
            .padding(.leading, viewModel.leadingContentOffset + 1) // 1 to leave space for the cursor
            .padding(.trailing, viewModel.trailingContentOffset + 2) // 2 to not overlap with the scrollbar
            .frame(width: geometry.size.width)
            .fixedSize()
            .padding(.top, viewModel.verticalContentOffset - (contentSize?.height ?? 0))
        } else {
          // Empty state with minimal size
          Color.clear.frame(width: 1, height: 1)
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
      .clipped()
      .border(.blue)
    }
  }

  @State private var contentSize: CGSize?

}
