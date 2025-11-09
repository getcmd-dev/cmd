// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

#if DEBUG
import ChatFoundation
import SwiftUI

#Preview {
  let tab1 = ChatThreadViewModel(name: "Login Flow", messages: [])
  let tab2 = ChatThreadViewModel(name: "API Integration", messages: [])
  let tab3 = ChatThreadViewModel(name: "New Chat", messages: [])
  tab3.hasUnreadCompletion = true

  return VStack {
    TabBarView(
      tabs: [tab1, tab2, tab3],
      currentTabIndex: 1,
      onSelectTab: { _ in },
      onCloseTab: { _ in },
      onAddTab: { })

    Spacer()
  }
  .frame(width: 400, height: 200)
}
#endif
