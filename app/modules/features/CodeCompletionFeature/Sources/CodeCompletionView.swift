// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

struct CodeCompletionView: View {
  @Bindable var viewModel: CodeCompletionViewModel
  var body: some View {
    VStack {
      HStack { Spacer() }
      if let completion = viewModel.completion {
        Text(completion.completion)
      }
      Spacer()
    }.padding(20)
  }
}
