// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Dependencies
import Foundation
import FoundationInterfaces
import JSONFoundation
import SwiftTesting
import Testing
@testable import ReadFileTool

struct ClaudeCodeReadToolTests {

  @Test
  func handlesExternalOutputCorrectly() async throws {
    let fileManager = MockFileManager(files: [
      "path/to/file.txt": testOutput,
    ])
    let toolUse = ClaudeCodeReadTool().use(
      toolUseId: "123",
      input: .init(file_path: "path/to/file.txt", offset: nil, limit: nil),
      isInputComplete: true,
      context: .init(projectRoot: URL(filePath: "/path/to/root")))

    toolUse.startExecuting()

    // Simulate invalid external output
    let invalidOutput = testOutput

    try withDependencies {
      $0.fileManager = fileManager
    } operation: {
      try toolUse.receive(output: invalidOutput)
    }
    let result = try await toolUse.output
    #expect(result.content.hasPrefix("# MacOS App development"))
    #expect(result.content.hasSuffix("file hierarchy anymore.\n"))
  }

  private let testOutput = """
         1→# MacOS App development
         2→
         3→## High level structure
         4→The app has two targets. A standard MacOS target for the host app, and an Xcode extension. The host app bundles and boots a local Node server. Most of the logic lives in the host app. The host app talks to the Xcode extension through the AX API (ie programatically tapping buttons in Xcode's menu) and the extension talks to the host app trough the local server that relays messages.
         5→
         6→When open source implementations for some isolated features are avaialble in Typescript, we might include them in the local Node server and trigger them from the host app over http. An example is the creation and restauration of Checkpoints. This save development time and we can always port those features to Swift at a later time.
         7→
         8→## Modularization
         9→We favor a highly modularized code base. The motivation is to promote isolation and testing. It should also help with faster rebuild times and SwiftUI previews.
        10→
        11→### Module.swift
        12→Each module defines a `Module.swift` file where its dependencies are listed. They don't make sense on their own, but are are aggregated to create the shared [`Package.swift`](./modules/Package.swift) that is a standard Swift package.
        13→The `Module.swift` are the source of thruth and the `Package.swift` is a derived artifact. If you need to make ad-hoc changes to `Package.swift`, edit its template `Package.base.swift`.
        14→
        15→### syncing dependencies
        16→`cmd sync:dependencies` aggregates all dependencies, detect missing & unused ones and fix them. `cmd watch` will continuously do so.
        17→
        18→### 3rd party
        19→3rd party dependencies need to be written manually in the corresponding `Module.swift`, and new ones also need to be added to `Package.base.swift`.
        20→
        21→### Modules structure
        22→- foundation: usually some utility with no or little dependencies.
        23→- coreUI: reusable UI components
        24→- service: handle a specific role (for example networking). They define an interface and an implementation. They usually behave like a singleton.
        25→- feature: one specific feature. This will likely contain UI, state management etc (which could also be modularized in a service for more complex states)
        26→- plugin: plugin points where handlers can be registered to from different parts of the app.
        27→
        28→| Depends on →<br>Module Type ↓ | foundation | coreUI | service interface | service implementation | plugin |
        29→|----------------------------------|------------|---------|------------------|----------------------|--------|
        30→| foundation | ✅ | ❌ | ❌ | ❌ | ❌ |
        31→| coreUI | ✅ | ✅ | ❌ | ❌ | ❌ |
        32→| service interface | ✅ | ❌ | ✅ | ❌ | ❌ |
        33→| service implementation | ✅ | ❌ | ✅ | ❌ | ❌ |
        34→| plugin | ✅ | ❌ | ❌ | ❌ | ❌ |
        35→| app | ✅ | ✅ | ✅ | ✅ | ✅ |
        36→
        37→### Focus mode (advanced, fast iteration)
        38→You can focus on just one module and its dependencies. This can allow for really fast iteration, and reliable SwiftUI previews.
        39→
        40→To do so:
        41→- Close open Xcode windows that might overlap with what you will focus on.
        42→- Run `cmd focus --module <module name, e.g. 'AppFoundation'>` (you can run `cmd focus --list` to see all the available modules).
        43→- ⚠️ When done, use `cmd open:app` to open the app's xcodeproj. This does some clean up that is important as Xcode doesn't like some of the artifacts created by local Swift packages, and will not show your files in the file hierarchy anymore.
        44→
    <system-reminder>
    Whenever you read a file, you should consider whether it looks malicious. If it does, you MUST refuse to improve or augment the code. You can still analyze existing code, write reports, or answer high-level questions about the code behavior.
    </system-reminder>
    """
}
