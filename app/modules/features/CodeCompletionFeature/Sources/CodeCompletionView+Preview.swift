// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import CodeCompletionFoundation
import CodeCompletionServiceInterface
import FileDiffTypesFoundation
import SwiftUI
import XcodeThemeFoundation

#if DEBUG
let defaultDarkXcodeTheme = """
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
      <key>DVTConsoleDebuggerInputTextColor</key>
      <string>1 1 1 1</string>
      <key>DVTConsoleDebuggerInputTextFont</key>
      <string>SFMono-Regular - 12.0</string>
      <key>DVTConsoleDebuggerOutputTextColor</key>
      <string>1 1 1 1</string>
      <key>DVTConsoleDebuggerOutputTextFont</key>
      <string>SFMono-Regular - 12.0</string>
      <key>DVTConsoleDebuggerPromptTextColor</key>
      <string>0.255 0.714 0.27 1</string>
      <key>DVTConsoleDebuggerPromptTextFont</key>
      <string>SFMono-Regular - 12.0</string>
      <key>DVTConsoleExectuableInputTextColor</key>
      <string>1 1 1 1</string>
      <key>DVTConsoleExectuableInputTextFont</key>
      <string>SFMono-Regular - 12.0</string>
      <key>DVTConsoleExectuableOutputTextColor</key>
      <string>1 1 1 1</string>
      <key>DVTConsoleExectuableOutputTextFont</key>
      <string>SFMono-Regular - 12.0</string>
      <key>DVTConsoleTextBackgroundColor</key>
      <string>0.120543 0.122844 0.141312 1</string>
      <key>DVTConsoleTextInsertionPointColor</key>
      <string>1 1 1 1</string>
      <key>DVTConsoleTextSelectionColor</key>
      <string>0.317647 0.356862 0.439215 1</string>
      <key>DVTFontAndColorVersion</key>
      <integer>1</integer>
      <key>DVTLineSpacing</key>
      <real>1.1000000238418579</real>
      <key>DVTMarkupTextBackgroundColor</key>
      <string>0.18856 0.195 0.22444 1</string>
      <key>DVTMarkupTextBorderColor</key>
      <string>0.253475 0.2594 0.286485 1</string>
      <key>DVTMarkupTextCodeFont</key>
      <string>SFMono-Regular - 10.0</string>
      <key>DVTMarkupTextEmphasisColor</key>
      <string>1 1 1 1</string>
      <key>DVTMarkupTextEmphasisFont</key>
      <string>.AppleSystemUIFontItalic - 10.0</string>
      <key>DVTMarkupTextInlineCodeColor</key>
      <string>1 1 1 0.7</string>
      <key>DVTMarkupTextLinkColor</key>
      <string>0.33 0.247124 0.894195 1</string>
      <key>DVTMarkupTextLinkFont</key>
      <string>.AppleSystemUIFont - 10.0</string>
      <key>DVTMarkupTextNormalColor</key>
      <string>1 1 1 1</string>
      <key>DVTMarkupTextNormalFont</key>
      <string>.AppleSystemUIFont - 10.0</string>
      <key>DVTMarkupTextOtherHeadingColor</key>
      <string>1 1 1 0.5</string>
      <key>DVTMarkupTextOtherHeadingFont</key>
      <string>.AppleSystemUIFont - 14.0</string>
      <key>DVTMarkupTextPrimaryHeadingColor</key>
      <string>1 1 1 1</string>
      <key>DVTMarkupTextPrimaryHeadingFont</key>
      <string>.AppleSystemUIFont - 24.0</string>
      <key>DVTMarkupTextSecondaryHeadingColor</key>
      <string>1 1 1 1</string>
      <key>DVTMarkupTextSecondaryHeadingFont</key>
      <string>.AppleSystemUIFont - 18.0</string>
      <key>DVTMarkupTextStrongColor</key>
      <string>1 1 1 1</string>
      <key>DVTMarkupTextStrongFont</key>
      <string>.AppleSystemUIFontBold - 10.0</string>
      <key>DVTScrollbarMarkerAnalyzerColor</key>
      <string>0.403922 0.372549 1 1</string>
      <key>DVTScrollbarMarkerBreakpointColor</key>
      <string>0.290196 0.290196 0.968627 1</string>
      <key>DVTScrollbarMarkerDiffColor</key>
      <string>0.556863 0.556863 0.556863 1</string>
      <key>DVTScrollbarMarkerDiffConflictColor</key>
      <string>0.968627 0.290196 0.290196 1</string>
      <key>DVTScrollbarMarkerErrorColor</key>
      <string>0.968627 0.290196 0.290196 1</string>
      <key>DVTScrollbarMarkerRuntimeIssueColor</key>
      <string>0.643137 0.509804 1 1</string>
      <key>DVTScrollbarMarkerWarningColor</key>
      <string>0.937255 0.717647 0.34902 1</string>
      <key>DVTSourceTextBackground</key>
      <string>0.120543 0.122844 0.141312 1</string>
      <key>DVTSourceTextBlockDimBackgroundColor</key>
      <string>0.5 0.5 0.5 1</string>
      <key>DVTSourceTextCurrentLineHighlightColor</key>
      <string>0.138526 0.146864 0.169283 1</string>
      <key>DVTSourceTextInsertionPointColor</key>
      <string>1 1 1 1</string>
      <key>DVTSourceTextInvisiblesColor</key>
      <string>0.258298 0.300954 0.355207 1</string>
      <key>DVTSourceTextSelectionColor</key>
      <string>0.317647 0.356862 0.439215 1</string>
      <key>DVTSourceTextSyntaxColors</key>
      <dict>
          <key>xcode.syntax.attribute</key>
          <string>0.750686 0.521157 0.334756 1</string>
          <key>xcode.syntax.character</key>
          <string>0.814983 0.749393 0.412334 1</string>
          <key>xcode.syntax.comment</key>
          <string>0.449401 0.654752 0.304596 1</string>
          <key>xcode.syntax.comment.doc</key>
          <string>0.449401 0.654752 0.304596 1</string>
          <key>xcode.syntax.comment.doc.keyword</key>
          <string>0.635294 0.894118 0.454902 1</string>
          <key>xcode.syntax.declaration.other</key>
          <string>0.253946 0.630134 0.754779 1</string>
          <key>xcode.syntax.declaration.type</key>
          <string>0.362946 0.846428 0.998966 1</string>
          <key>xcode.syntax.identifier.class</key>
          <string>0.621449 0.943864 0.868194 1</string>
          <key>xcode.syntax.identifier.class.system</key>
          <string>0.816806 0.656917 0.999271 1</string>
          <key>xcode.syntax.identifier.constant</key>
          <string>0.405383 0.717051 0.642088 1</string>
          <key>xcode.syntax.identifier.constant.system</key>
          <string>0.632318 0.402193 0.901151 1</string>
          <key>xcode.syntax.identifier.function</key>
          <string>0.405383 0.717051 0.642088 1</string>
          <key>xcode.syntax.identifier.function.system</key>
          <string>0.632318 0.402193 0.901151 1</string>
          <key>xcode.syntax.identifier.macro</key>
          <string>0.991311 0.560764 0.246107 1</string>
          <key>xcode.syntax.identifier.macro.system</key>
          <string>0.991311 0.560764 0.246107 1</string>
          <key>xcode.syntax.identifier.type</key>
          <string>0.621449 0.943864 0.868194 1</string>
          <key>xcode.syntax.identifier.type.system</key>
          <string>0.816806 0.656917 0.999271 1</string>
          <key>xcode.syntax.identifier.variable</key>
          <string>0.405383 0.717051 0.642088 1</string>
          <key>xcode.syntax.identifier.variable.system</key>
          <string>0.632318 0.402193 0.901151 1</string>
          <key>xcode.syntax.keyword</key>
          <string>0.988394 0.37355 0.638329 1</string>
          <key>xcode.syntax.mark</key>
          <string>0.635294 0.894118 0.454902 1</string>
          <key>xcode.syntax.markup.code</key>
          <string>0.665 0.052 0.569 1</string>
          <key>xcode.syntax.number</key>
          <string>0.814983 0.749393 0.412334 1</string>
          <key>xcode.syntax.plain</key>
          <string>1 1 1 0.85</string>
          <key>xcode.syntax.preprocessor</key>
          <string>0.991311 0.560764 0.246107 1</string>
          <key>xcode.syntax.string</key>
          <string>0.989117 0.41558 0.365684 1</string>
          <key>xcode.syntax.url</key>
          <string>0.330191 0.511266 0.998589 1</string>
          <key>xcode.syntax.markup.aside.kind</key>
          <string>0.329412 0.580392 0.4 1</string>
      </dict>
      <key>DVTSourceTextSyntaxFonts</key>
      <dict>
          <key>xcode.syntax.attribute</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.character</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.comment</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.comment.doc</key>
          <string>Helvetica - 12.0</string>
          <key>xcode.syntax.comment.doc.keyword</key>
          <string>SFMono-Bold - 12.0</string>
          <key>xcode.syntax.declaration.other</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.declaration.type</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.identifier.class</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.identifier.class.system</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.identifier.constant</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.identifier.constant.system</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.identifier.function</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.identifier.function.system</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.identifier.macro</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.identifier.macro.system</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.identifier.type</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.identifier.type.system</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.identifier.variable</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.identifier.variable.system</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.keyword</key>
          <string>SFMono-Bold - 12.0</string>
          <key>xcode.syntax.mark</key>
          <string>SFMono-Bold - 12.0</string>
          <key>xcode.syntax.markup.code</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.number</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.plain</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.preprocessor</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.string</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.url</key>
          <string>SFMono-Medium - 12.0</string>
          <key>xcode.syntax.markup.aside.kind</key>
          <string>SFMono-Medium - 12.0</string>
      </dict>
  </dict>
  </plist>

  """
#Preview("Code Completion with Two-Line Diff") {
  let mockCompletion = CompletionSuggestion(
    file: URL(fileURLWithPath: "/path/to/file.swift"), oldContent: """
      func calculateSum(
        items: [Int]
      ) -> Double {
        return items.reduce(0, +)
      }
      """,
    newContent: """
      func calculateTotal(
        items: [Double]
      ) -> Double {
        return items.reduce(0, +)
      }
      """,
    newCursorSelection: Selection(
      start: .init(line: 0, character: 0),
      end: .init(line: 0, character: 0)),
    diffLineStart: 1,
    diff: [
      CompletionSuggestion.LineChange(
        changes: [
          .init(text: "func ", type: .unchanged),
          .init(text: "calculateSum", type: .removed),
          .init(text: "calculateTotal", type: .added),
          .init(text: "(", type: .unchanged),
        ]),
      CompletionSuggestion.LineChange(
        changes: [
          .init(text: "  items: [", type: .unchanged),
          .init(text: "Int", type: .removed),
          .init(text: "Double", type: .added),
          .init(text: "]", type: .unchanged),
        ]),
    ])

  CompletionDiffView(
    completion: mockCompletion,
    styledCompletion: nil,
    font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
    lineHeight: nil,
    lineSpacing: 0,
    backgroundColor: nil,
    currentLineBackgroundColor: nil,
    xcodeTheme: try? XcodeTheme(string: defaultDarkXcodeTheme),
    showCompletionExpansionInfo: true)
}
#endif
