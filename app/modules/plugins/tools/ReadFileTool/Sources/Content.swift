// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

#if DEBUG

import Dependencies
import Foundation
import HighlighterServiceInterface
import Observation

@Observable
@MainActor
final class Highlighter {

  init(_ content: String) {
    self.content = content
    Task {
      attributedString = try await highlighter.attributedText(content, language: .swift)
    }
  }

  private(set) var attributedString: AttributedString?

  private let content: String
  @ObservationIgnored
  @Dependency(\.highlighter) private var highlighter
}

let longContent = """
  // swift-tools-version: 6.0
  // The swift-tools-version declares the minimum version of Swift required to build this package.

  import CompilerPluginSupport
  import PackageDescription

  let package = Package(
    name: "Packages",
    platforms: [
      .macOS("15.2"),
    ],
    products: [
      .library(
        name: "App",
        targets: [
          "App",
        ]),
      .library(
        name: "AppExtension",
        targets: [
          "AppExtension",
        ]),
    ],
    dependencies: [
      .package(url: "https://github.com/appstefan/highlightswift.git", from: "1.1.0"),
      .package(url: "https://github.com/gsabran/Down", revision: "dade552d333ad0e2231250c1a596ce12bea8705b"),
      .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.7.0"),
      .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.6.0"),
      .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.0"),
      .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.2.4"),
      .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.1"),
    ],
    targets: [
      .target(
        name: "App",
        dependencies: [
          .product(name: "Dependencies", package: "swift-dependencies"),
          .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
          "AccessibilityFoundation",
          "AccessibilityObjCFoundation",
          "AppEventService",
          "AppEventServiceInterface",
          "Chat",
          "ChatAppEvents",
          "DependencyFoundation",
          "DLS",
          "ExtensionCommandHandler",
          "FileEditService",
          "FileEditServiceInterface",
          "FoundationInterfaces",
          "LLMService",
          "LLMServiceInterface",
          "LoggingService",
          "LoggingServiceInterface",
          "LSTool",
          "ExecuteCommandTool",
          "PermissionsService",
          "PermissionsServiceInterface",
          "ReadFileTool",
          "RepeatTool",
          "SearchFilesTool",
          "LocalServerService",
          "LocalServerServiceInterface",
          "ShellService",
          "ShellServiceInterface",
          "ThreadSafe",
          "ToolFoundation",
          "XcodeControllerService",
          "XcodeControllerServiceInterface",
          "XcodeObserverService",
          "XcodeObserverServiceInterface",
        ],
        path: "App/Sources",
        resources: [
        ]),
      .testTarget(
        name: "AppTests",
        dependencies: [
        ],
        path: "App/Tests"),
      .target(
        name: "AppExtension",
        dependencies: [
          "AccessibilityFoundation",
          "FoundationInterfaces",
          "LoggingServiceInterface",
          "SharedValuesFoundation",
        ],
        path: "AppExtension/Sources"),
      // Core UI
      .target(
        name: "CodePreview",
        dependencies: [
          "AppFoundation",
          "ConcurrencyFoundation",
          "DLS",
          "FileDiffFoundation",
          "FileDiffTypesFoundation",
          "FileEditServiceInterface",
          "FoundationInterfaces",
          "LoggingServiceInterface",
        ],
        path: "coreui/CodePreview/Sources"),
      .testTarget(
        name: "CodePreviewTests",
        dependencies: [
          "AppFoundation",
          "CodePreview",
          "ConcurrencyFoundation",
          "FileDiffFoundation",
          "FileDiffTypesFoundation",
          "FileEditServiceInterface",
          "FoundationInterfaces",
          "LoggingServiceInterface",
          "SwiftTesting",
        ],
        path: "coreui/CodePreview/Tests"),
      .target(
        name: "DLS",
        dependencies: [
          "ConcurrencyFoundation",
          "LoggingServiceInterface",
        ],
        path: "coreui/DLS/Sources",
        resources: [
          .process("Resources/fileIcons"),
        ]),
      // Features
      .target(
        name: "Chat",
        dependencies: [
          .product(name: "Down", package: "Down"),
          .product(name: "HighlightSwift", package: "highlightswift"),
          "AppEventServiceInterface",
          "AppFoundation",
          "ChatAppEvents",
          "CodePreview",
          "ConcurrencyFoundation",
          "DLS",
          "FileDiffFoundation",
          "FileDiffTypesFoundation",
          "FileEditServiceInterface",
          "FoundationInterfaces",
          "JSONFoundation",
          "LLMServiceInterface",
          "LoggingServiceInterface",
          "LocalServerServiceInterface",
          "ToolFoundation",
          "XcodeObserverServiceInterface",
        ],
        path: "features/Chat/Sources"),
      .testTarget(
        name: "ChatTests",
        dependencies: [
          "Chat",
        ],
        path: "features/Chat/Tests"),
      .target(
        name: "AccessibilityFoundation",
        dependencies: [
          "ConcurrencyFoundation",
          "LoggingServiceInterface",
        ],
        path: "foundations/AccessibilityFoundation/Sources"),
      .testTarget(
        name: "AccessibilityFoundationTests",
        dependencies: [
          "AccessibilityFoundation",
        ],
        path: "foundations/AccessibilityFoundation/Tests"),
      .target(
        name: "AccessibilityObjCFoundation",
        dependencies: [
        ],
        path: "foundations/AccessibilityObjCFoundation/Sources",
        publicHeadersPath: "include"),
      .target(
        name: "AppFoundation",
        dependencies: [
        ],
        path: "foundations/AppFoundation/Sources"),
      .testTarget(
        name: "AppFoundationTests",
        dependencies: [
          "AppFoundation",
        ],
        path: "foundations/AppFoundation/Tests"),
      .target(
        name: "ChatAppEvents",
        dependencies: [
          "AppEventServiceInterface",
        ],
        path: "foundations/ChatAppEvents/Sources"),
      .target(
        name: "ConcurrencyFoundation",
        dependencies: [
        ],
        path: "foundations/ConcurrencyFoundation/Sources"),
      .testTarget(
        name: "ConcurrencyFoundationTests",
        dependencies: [
          "ConcurrencyFoundation",
          "SwiftTesting",
        ],
        path: "foundations/ConcurrencyFoundation/Tests"),
      .target(
        name: "DependencyFoundation",
        dependencies: [
          .product(name: "Dependencies", package: "swift-dependencies"),
        ],
        path: "foundations/DependencyFoundation/Sources"),
      .target(
        name: "FileDiffFoundation",
        dependencies: [
          .product(name: "HighlightSwift", package: "highlightswift"),
          "AppFoundation",
          "FileDiffTypesFoundation",
          "LoggingServiceInterface",
        ],
        path: "foundations/FileDiffFoundation/Sources"),
      .testTarget(
        name: "FileDiffFoundationTests",
        dependencies: [
          .product(name: "HighlightSwift", package: "highlightswift"),
          .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
          "FileDiffFoundation",
          "FileDiffTypesFoundation",
        ],
        path: "foundations/FileDiffFoundation/Tests",
        exclude: ["__Snapshots__"]),
      .target(
        name: "FileDiffTypesFoundation",
        dependencies: [
        ],
        path: "foundations/FileDiffTypesFoundation/Sources"),
      .target(
        name: "FoundationInterfaces",
        dependencies: [
          "ConcurrencyFoundation",
          "DependencyFoundation",
          "ThreadSafe",
        ],
        path: "foundations/FoundationInterfaces/Sources"),
      .testTarget(
        name: "FoundationInterfacesTests",
        dependencies: [
        ],
        path: "foundations/FoundationInterfaces/Tests"),
      .target(
        name: "JSONFoundation",
        dependencies: [
        ],
        path: "foundations/JSONFoundation/Sources"),
      .testTarget(
        name: "JSONFoundationTests",
        dependencies: [
        ],
        path: "foundations/JSONFoundation/Tests"),
      .target(
        name: "SharedValuesFoundation",
        dependencies: [
          "FileDiffFoundation",
        ],
        path: "foundations/SharedValuesFoundation/Sources"),
      .target(
        name: "StringFoundation",
        dependencies: [
        ],
        path: "foundations/StringFoundation/Sources"),
      .testTarget(
        name: "StringFoundationTests",
        dependencies: [
          "StringFoundation",
        ],
        path: "foundations/StringFoundation/Tests"),
      .target(
        name: "ToolFoundation",
        dependencies: [
          "AppFoundation",
          "ConcurrencyFoundation",
          "DependencyFoundation",
          "JSONFoundation",
          "ThreadSafe",
        ],
        path: "foundations/ToolFoundation/Sources"),
      .testTarget(
        name: "ToolFoundationTests",
        dependencies: [
        ],
        path: "foundations/ToolFoundation/Tests"),
      .target(
        name: "ThreadSafe",
        dependencies: [
          .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
          .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
          "ConcurrencyFoundation",
          "ThreadSafeMacro",
        ],
        path: "macros/ThreadSafe/Plugin"),
      .macro(
        name: "ThreadSafeMacro",
        dependencies: [
          .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
          .product(name: "SwiftSyntax", package: "swift-syntax"),
          .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
          "ConcurrencyFoundation",
        ],
        path: "macros/ThreadSafe/Sources"),
      .testTarget(
        name: "ThreadSafeMacroTests",
        dependencies: [
          .product(name: "MacroTesting", package: "swift-macro-testing"),
          .product(name: "SwiftSyntax", package: "swift-syntax"),
          .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
          "ThreadSafeMacro",
        ],
        path: "macros/ThreadSafe/Tests"),
      .target(
        name: "ExtensionCommandHandler",
        dependencies: [
          .product(name: "Dependencies", package: "swift-dependencies"),
          "AppEventServiceInterface",
          "ExtensionEventsInterface",
          "LoggingServiceInterface",
          "SharedValuesFoundation",
          "ShellServiceInterface",
          "XcodeObserverServiceInterface",
        ],
        path: "plugins/ExtensionCommandHandler/Sources"),
      .target(
        name: "LSTool",
        dependencies: [
          "AppFoundation",
          "ConcurrencyFoundation",
          "DLS",
          "JSONFoundation",
          "LLMServiceInterface",
          "LocalServerServiceInterface",
          "ToolFoundation",
        ],
        path: "plugins/tools/LSTool/Sources"),
      .testTarget(
        name: "LSToolTests",
        dependencies: [
          "LLMServiceInterface",
          "LSTool",
          "LocalServerServiceInterface",
          "SwiftTesting",
        ],
        path: "plugins/tools/LSTool/Tests"),
      .target(
        name: "ExecuteCommandTool",
        dependencies: [
          "AppFoundation",
          "ConcurrencyFoundation",
          "DLS",
          "JSONFoundation",
          "LLMServiceInterface",
          "LocalServerServiceInterface",
          "ToolFoundation",
          "ShellServiceInterface",
        ],
        path: "plugins/tools/ExecuteCommandTool/Sources"),
      .testTarget(
        name: "ExecuteCommandToolTests",
        dependencies: [
          "LLMServiceInterface",
          "LocalServerServiceInterface",
          "SwiftTesting",
          "ExecuteCommandTool",
        ],
        path: "plugins/tools/ExecuteCommandTool/Tests"),
      .target(
        name: "ReadFileTool",
        dependencies: [
          "CodePreview",
          "DLS",
          "FoundationInterfaces",
          "JSONFoundation",
          "LLMServiceInterface",
          "LocalServerServiceInterface",
          "ToolFoundation",
        ],
        path: "plugins/tools/ReadFileTool/Sources"),
      .testTarget(
        name: "ReadFileToolTests",
        dependencies: [
          "FoundationInterfaces",
          "LLMServiceInterface",
          "ReadFileTool",
          "SwiftTesting",
        ],
        path: "plugins/tools/ReadFileTool/Tests"),
      .target(
        name: "RepeatTool",
        dependencies: [
          "ConcurrencyFoundation",
          "JSONFoundation",
          "ToolFoundation",
        ],
        path: "plugins/tools/RepeatTool/Sources"),
      .testTarget(
        name: "RepeatToolTests",
        dependencies: [
        ],
        path: "plugins/tools/RepeatTool/Tests"),
      .target(
        name: "SearchFilesTool",
        dependencies: [
          "AppFoundation",
          "ConcurrencyFoundation",
          "DLS",
          "JSONFoundation",
          "LLMServiceInterface",
          "LocalServerServiceInterface",
          "ToolFoundation",
        ],
        path: "plugins/tools/SearchFilesTool/Sources"),
      .testTarget(
        name: "SearchFilesToolTests",
        dependencies: [
          "LLMServiceInterface",
          "SearchFilesTool",
          "LocalServerServiceInterface",
          "SwiftTesting",
        ],
        path: "plugins/tools/SearchFilesTool/Tests"),
      .target(
        name: "AppEventServiceInterface",
        dependencies: [
          .product(name: "Dependencies", package: "swift-dependencies"),
          "ConcurrencyFoundation",
        ],
        path: "serviceInterfaces/AppEventServiceInterface/Sources"),
      .target(
        name: "ExtensionEventsInterface",
        dependencies: [
          "AppEventServiceInterface",
        ],
        path: "serviceInterfaces/ExtensionEventsInterface/Sources"),
      .target(
        name: "FileEditServiceInterface",
        dependencies: [
          .product(name: "Dependencies", package: "swift-dependencies"),
          "FileDiffTypesFoundation",
          "ThreadSafe",
        ],
        path: "serviceInterfaces/FileEditServiceInterface/Sources"),
      .testTarget(
        name: "FileEditServiceInterfaceTests",
        dependencies: [
        ],
        path: "serviceInterfaces/FileEditServiceInterface/Tests"),
      .target(
        name: "LLMServiceInterface",
        dependencies: [
          .product(name: "Dependencies", package: "swift-dependencies"),
          "ConcurrencyFoundation",
          "JSONFoundation",
          "LocalServerServiceInterface",
          "ThreadSafe",
          "ToolFoundation",
        ],
        path: "serviceInterfaces/LLMServiceInterface/Sources"),
      .testTarget(
        name: "LLMServiceInterfaceTests",
        dependencies: [
        ],
        path: "serviceInterfaces/LLMServiceInterface/Tests"),
      .target(
        name: "LoggingServiceInterface",
        dependencies: [
          .product(name: "Dependencies", package: "swift-dependencies"),
          "ThreadSafe",
        ],
        path: "serviceInterfaces/LoggingServiceInterface/Sources"),
      .testTarget(
        name: "LoggingServiceInterfaceTests",
        dependencies: [
          "LoggingServiceInterface",
        ],
        path: "serviceInterfaces/LoggingServiceInterface/Tests"),
      .target(
        name: "PermissionsServiceInterface",
        dependencies: [
          .product(name: "Dependencies", package: "swift-dependencies"),
        ],
        path: "serviceInterfaces/PermissionsServiceInterface/Sources"),
      .testTarget(
        name: "PermissionsServiceInterfaceTests",
        dependencies: [
          "PermissionsServiceInterface",
        ],
        path: "serviceInterfaces/PermissionsServiceInterface/Tests"),
      .target(
        name: "LocalServerServiceInterface",
        dependencies: [
          .product(name: "Dependencies", package: "swift-dependencies"),
          "AppFoundation",
          "ConcurrencyFoundation",
          "JSONFoundation",
        ],
        path: "serviceInterfaces/LocalServerServiceInterface/Sources"),
      .testTarget(
        name: "LocalServerServiceInterfaceTests",
        dependencies: [
          "ConcurrencyFoundation",
          "LocalServerServiceInterface",
          "SwiftTesting",
        ],
        path: "serviceInterfaces/LocalServerServiceInterface/Tests"),
      .target(
        name: "ShellServiceInterface",
        dependencies: [
          .product(name: "Dependencies", package: "swift-dependencies"),
          "ConcurrencyFoundation",
          "LoggingServiceInterface",
          "ThreadSafe",
        ],
        path: "serviceInterfaces/ShellServiceInterface/Sources"),
      .testTarget(
        name: "ShellServiceInterfaceTests",
        dependencies: [
          "ShellServiceInterface",
        ],
        path: "serviceInterfaces/ShellServiceInterface/Tests"),
      .target(
        name: "XcodeControllerServiceInterface",
        dependencies: [
          .product(name: "Dependencies", package: "swift-dependencies"),
          "FileDiffFoundation",
          "FileDiffTypesFoundation",
          "ThreadSafe",
        ],
        path: "serviceInterfaces/XcodeControllerServiceInterface/Sources"),
      .target(
        name: "XcodeObserverServiceInterface",
        dependencies: [
          .product(name: "Dependencies", package: "swift-dependencies"),
          "AccessibilityFoundation",
        ],
        path: "serviceInterfaces/XcodeObserverServiceInterface/Sources"),
      .testTarget(
        name: "XcodeObserverServiceInterfaceTests",
        dependencies: [
          "XcodeObserverServiceInterface",
        ],
        path: "serviceInterfaces/XcodeObserverServiceInterface/Tests"),
      .target(
        name: "AppEventService",
        dependencies: [
          "AppEventServiceInterface",
          "DependencyFoundation",
          "LoggingServiceInterface",
        ],
        path: "services/AppEventService/Sources"),
      .target(
        name: "FileEditService",
        dependencies: [
          "AppFoundation",
          "ConcurrencyFoundation",
          "DependencyFoundation",
          "FileEditServiceInterface",
          "FoundationInterfaces",
          "LoggingServiceInterface",
          "XcodeControllerServiceInterface",
          "XcodeObserverServiceInterface",
        ],
        path: "services/FileEditService/Sources"),
      .testTarget(
        name: "FileEditServiceTests",
        dependencies: [
        ],
        path: "services/FileEditService/Tests"),
      .target(
        name: "LLMService",
        dependencies: [
          "AppFoundation",
          "ConcurrencyFoundation",
          "DependencyFoundation",
          "FoundationInterfaces",
          "JSONFoundation",
          "LLMServiceInterface",
          "LoggingServiceInterface",
          "LocalServerServiceInterface",
          "ToolFoundation",
          "XcodeObserverServiceInterface",
        ],
        path: "services/LLMService/Sources"),
      .testTarget(
        name: "LLMServiceTests",
        dependencies: [
          "ConcurrencyFoundation",
          "FoundationInterfaces",
          "JSONFoundation",
          "LLMService",
          "LLMServiceInterface",
          "LocalServerServiceInterface",
          "SwiftTesting",
          "ToolFoundation",
          "XcodeObserverServiceInterface",
        ],
        path: "services/LLMService/Tests"),
      .target(
        name: "LoggingService",
        dependencies: [
          "DependencyFoundation",
          "LoggingServiceInterface",
          "ThreadSafe",
        ],
        path: "services/LoggingService/Sources"),
      .testTarget(
        name: "LoggingServiceTests",
        dependencies: [
          "LoggingService",
        ],
        path: "services/LoggingService/Tests"),
      .target(
        name: "PermissionsService",
        dependencies: [
          "AppFoundation",
          "DependencyFoundation",
          "LoggingServiceInterface",
          "PermissionsServiceInterface",
          "ShellServiceInterface",
        ],
        path: "services/PermissionsService/Sources"),
      .testTarget(
        name: "PermissionsServiceTests",
        dependencies: [
          "ConcurrencyFoundation",
          "LoggingServiceInterface",
          "PermissionsService",
          "ShellServiceInterface",
        ],
        path: "services/PermissionsService/Tests"),
      .target(
        name: "LocalServerService",
        dependencies: [
          "AppEventServiceInterface",
          "AppFoundation",
          "DependencyFoundation",
          "ExtensionEventsInterface",
          "FoundationInterfaces",
          "LoggingServiceInterface",
          "LocalServerServiceInterface",
          "ThreadSafe",
        ],
        path: "services/LocalServerService/Sources",
        resources: [.process("Resources")]),
      .testTarget(
        name: "LocalServerServiceTests",
        dependencies: [
          "JSONFoundation",
          "LocalServerService",
          "LocalServerServiceInterface",
          "SwiftTesting",
        ],
        path: "services/LocalServerService/Tests"),
      .target(
        name: "ShellService",
        dependencies: [
          "ConcurrencyFoundation",
          "DependencyFoundation",
          "LoggingServiceInterface",
          "ShellServiceInterface",
          "ThreadSafe",
        ],
        path: "services/ShellService/Sources"),
      .testTarget(
        name: "ShellServiceTests",
        dependencies: [
          "ShellService",
        ],
        path: "services/ShellService/Tests",
        exclude: ["SwiftPrintTest.swift.sh", "simple_output.sh"],
        resources: [
          .process("SwiftPrintTest.swift.sh"),
          .process("simple_output.sh"),
        ]),
      .target(
        name: "XcodeControllerService",
        dependencies: [
          "AppEventServiceInterface",
          "AppFoundation",
          "ConcurrencyFoundation",
          "DependencyFoundation",
          "ExtensionEventsInterface",
          "FileDiffFoundation",
          "LoggingServiceInterface",
          "SharedValuesFoundation",
          "ShellServiceInterface",
          "XcodeControllerServiceInterface",
          "XcodeObserverServiceInterface",
        ],
        path: "services/XcodeControllerService/Sources"),
      .testTarget(
        name: "XcodeControllerServiceTests",
        dependencies: [
          "AppEventServiceInterface",
          "AppFoundation",
          "ConcurrencyFoundation",
          "ExtensionEventsInterface",
          "SharedValuesFoundation",
          "ShellServiceInterface",
          "SwiftTesting",
          "XcodeControllerService",
          "XcodeControllerServiceInterface",
          "XcodeObserverServiceInterface",
        ],
        path: "services/XcodeControllerService/Tests"),
      .target(
        name: "XcodeObserverService",
        dependencies: [
          "AccessibilityFoundation",
          "ConcurrencyFoundation",
          "DependencyFoundation",
          "LoggingServiceInterface",
          "PermissionsServiceInterface",
          "StringFoundation",
          "ThreadSafe",
          "XcodeObserverServiceInterface",
        ],
        path: "services/XcodeObserverService/Sources"),
      .testTarget(
        name: "XcodeObserverServiceTests",
        dependencies: [
          "XcodeObserverService",
        ],
        path: "services/XcodeObserverService/Tests"),
      // Dependency only meant for testing
      .target(
        name: "SwiftTesting",
        dependencies: [
          "ConcurrencyFoundation",
        ],
        path: "SwiftTesting/Sources"),
    ])

  """
#endif
