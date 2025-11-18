// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

#if DEBUG
public struct RouterPreview: PreviewModifier {
  let router = Router(registry: .init())

  public static func makeSharedContext() async throws -> NSManagedObjectContext {
    .init()
  }

  public typealias Context = NSManagedObjectContext

  public func body(content: Content, context _: Context) -> some View {
    content
      .environment(router)
  }
}

extension PreviewTrait where T == Preview.ViewTraits {
  @MainActor public static var emptyRouter = Self.modifier(RouterPreview())
}
#endif
