// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - ThreeDotsLoadingAnimation

public struct ThreeDotsLoadingAnimation: View {
  public init(baseText: String = "", duration: TimeInterval = 2) {
    self.baseText = baseText
    self.duration = duration
  }

  public var body: some View {
    Text(text)
      .onAppear {
        startAnimation()
      }
  }

  @State private var i = 0

  private let duration: TimeInterval
  private let baseText: String

  private var text: String {
    baseText + String(repeating: ".", count: i) + String(repeating: " ", count: 4 - i)
  }

  private func startAnimation() {
    let stepDuration = duration / 4 // 4 steps: "", ".", "..", "..."

    Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { _ in
      Task { @MainActor in
        withAnimation(.easeInOut(duration: stepDuration * 0.3)) {
          i = (i + 1) % 4
        }
      }
    }
  }
}

#if DEBUG
#Preview {
  ThreeDotsLoadingAnimation(duration: 2)
}
#endif
