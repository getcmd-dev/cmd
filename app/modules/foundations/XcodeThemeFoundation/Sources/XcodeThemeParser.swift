// swiftformat:disable all
// Copied from https://github.com/intitni/CopilotForXcode/blob/main/Core/Sources/XcodeThemeController/XcodeThemeParser.swift

import Foundation
import AppKit

public struct XcodeTheme: Codable, Sendable {
    public struct ThemeColor: Codable, Sendable {
        public var red: Double
        public var green: Double
        public var blue: Double
        public var alpha: Double

        public var hexString: String {
            let red = Int(self.red * 255)
            let green = Int(self.green * 255)
            let blue = Int(self.blue * 255)
            let alpha = Int(self.alpha * 255)
            return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
        }
        
        var storable: XcodeTheme.ThemeColor {
            .init(red: red, green: green, blue: blue, alpha: alpha)
        }
    }

    public struct ThemeFont: Codable, Sendable {
        public var name: String
        public var size: Double

        var storable: XcodeTheme.ThemeFont {
            .init(name: name, size: size)
        }
    }

    public var plainTextColor: ThemeColor?
    public var plainTextFont: ThemeFont
    public var commentColor: ThemeColor?
    public var documentationMarkupColor: ThemeColor?
    public var documentationMarkupKeywordColor: ThemeColor?
    public var marksColor: ThemeColor?
    public var stringsColor: ThemeColor?
    public var charactersColor: ThemeColor?
    public var numbersColor: ThemeColor?
    public var regexLiteralsColor: ThemeColor?
    public var regexLiteralNumbersColor: ThemeColor?
    public var regexLiteralCaptureNamesColor: ThemeColor?
    public var regexLiteralCharacterClassNamesColor: ThemeColor?
    public var regexLiteralOperatorsColor: ThemeColor?
    public var keywordsColor: ThemeColor?
    public var preprocessorStatementsColor: ThemeColor?
    public var urlsColor: ThemeColor?
    public var attributesColor: ThemeColor?
    public var typeDeclarationsColor: ThemeColor?
    public var otherDeclarationsColor: ThemeColor?
    public var projectClassNamesColor: ThemeColor?
    public var projectFunctionAndMethodNamesColor: ThemeColor?
    public var projectConstantsColor: ThemeColor?
    public var projectTypeNamesColor: ThemeColor?
    public var projectPropertiesAndGlobalsColor: ThemeColor?
    public var projectPreprocessorMacrosColor: ThemeColor?
    public var otherClassNamesColor: ThemeColor?
    public var otherFunctionAndMethodNamesColor: ThemeColor?
    public var otherConstantsColor: ThemeColor?
    public var otherTypeNamesColor: ThemeColor?
    public var otherPropertiesAndGlobalsColor: ThemeColor?
    public var otherPreprocessorMacrosColor: ThemeColor?
    public var headingColor: ThemeColor?
    public var backgroundColor: ThemeColor?
    public var selectionColor: ThemeColor?
    public var cursorColor: ThemeColor?
    public var currentLineColor: ThemeColor?
    public var invisibleCharactersColor: ThemeColor?
    public var debuggerConsolePromptColor: ThemeColor?
    public var debuggerConsoleOutputColor: ThemeColor?
    public var debuggerConsoleInputColor: ThemeColor?
    public var executableConsoleOutputColor: ThemeColor?
    public var executableConsoleInputColor: ThemeColor?
}

public extension XcodeTheme {
    /// Color scheme locations:
    /// ~/Library/Developer/Xcode/UserData/FontAndColorThemes/
    /// Xcode.app/Contents/SharedFrameworks/DVTUserInterfaceKit.framework/Versions/A/Resources/FontAndColorThemes
    init(fileURL: URL) throws {
        let parser = XcodeThemeParser()
        self = try parser.parse(fileURL: fileURL)
    }
    #if DEBUG
    init(string: String) throws {
        let parser = XcodeThemeParser()
        let data = string.data(using: .utf8)!
        self = try parser.parseXCColorTheme(data)
    }
    #endif
}

struct XcodeThemeParser {
    enum Error: Swift.Error {
        case fileNotFound
        case invalidData
    }
    
    func parse(fileURL: URL) throws -> XcodeTheme {
        guard let data = try? Data(contentsOf: fileURL) else {
            throw Error.fileNotFound
        }

        if fileURL.pathExtension == "xccolortheme" {
            return try parseXCColorTheme(data)
        } else {
            throw Error.invalidData
        }
    }

    func parseXCColorTheme(_ data: Data) throws -> XcodeTheme {
        let plist = try? PropertyListSerialization.propertyList(
            from: data,
            options: .mutableContainers,
            format: nil
        ) as? [String: Any]

        guard let theme = plist else { throw Error.invalidData }

        func getRawThemeValue(at path: [String]) -> String? {
            guard !path.isEmpty else { return nil }
            let keys = path.dropLast(1)
            var currentDict = theme
            for key in keys {
                guard let value = currentDict[key] as? [String: Any] else {
                    return nil
                }
                currentDict = value
            }
            return currentDict[path.last!] as? String
        }

        /// The source value is an `r g b a` string, for example: `0.5 0.5 0.2 1`
        func convertColor(source: String) -> XcodeTheme.ThemeColor {
            let components = source.split(separator: " ")
            let red = (components[0] as NSString).doubleValue
            let green = (components[1] as NSString).doubleValue
            let blue = (components[2] as NSString).doubleValue
            let alpha = (components[3] as NSString).doubleValue
            return .init(red: red, green: green, blue: blue, alpha: alpha)
        }

        func getThemeValue(
            at path: [String]
        ) -> XcodeTheme.ThemeColor? {
            if let value = getRawThemeValue(at: path) {
                return convertColor(source: value)
            }
            return nil
        }

        /// The source value is an `FontName - size` string, for example: `SFMono-Medium - 12.0`
        func convertFont(source: String) -> XcodeTheme.ThemeFont? {
            if let separator = source.range(of: " - ") {
                let name = String(source.prefix(upTo: separator.lowerBound))
                let size = Double(source.suffix(from: separator.upperBound)) ?? 0.0
                return .init(name: name, size: size)
            }
            return nil
        }

        func getThemeFont(
            at path: [String],
            defaultValue: XcodeTheme.ThemeFont = .init(name: "SFMono-Medium", size: 12.0)
        ) -> XcodeTheme.ThemeFont {
            if let value = getRawThemeValue(at: path) {
                return convertFont(source: value) ?? defaultValue
            }
            return defaultValue
        }

        let xcodeTheme = XcodeTheme(
            plainTextColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.plain"]),
            plainTextFont: getThemeFont(
                at: ["DVTSourceTextSyntaxFonts", "xcode.syntax.plain"]
            ),
            commentColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.comment"]),
            documentationMarkupColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.comment.doc"]),
            documentationMarkupKeywordColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.comment.doc.keyword"]),
            marksColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.mark"]),
            stringsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.string"]),
            charactersColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.character"]),
            numbersColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.number"]),
            regexLiteralsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.plain"]),
            regexLiteralNumbersColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.number"]),
            regexLiteralCaptureNamesColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.plain"]),
            regexLiteralCharacterClassNamesColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.plain"]),
            regexLiteralOperatorsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.plain"]),
            keywordsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.keyword"]),
            preprocessorStatementsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.preprocessor"]),
            urlsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.url"]),
            attributesColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.attribute"]),
            typeDeclarationsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.declaration.type"]),
            otherDeclarationsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.declaration.other"]),
            projectClassNamesColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.class"]),
            projectFunctionAndMethodNamesColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.function"]),
            projectConstantsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.constant"]),
            projectTypeNamesColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.type"]),
            projectPropertiesAndGlobalsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.variable"]),
            projectPreprocessorMacrosColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.macro"]),
            otherClassNamesColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.class.system"]),
            otherFunctionAndMethodNamesColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.function.system"]),
            otherConstantsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.constant.system"]),
            otherTypeNamesColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.type.system"]),
            otherPropertiesAndGlobalsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.variable.system"]),
            otherPreprocessorMacrosColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.macro.system"]),
            headingColor: getThemeValue(
                at: ["DVTMarkupTextPrimaryHeadingColor"]),
            backgroundColor: getThemeValue(
                at: ["DVTSourceTextBackground"]),
            selectionColor: getThemeValue(
                at: ["DVTSourceTextSelectionColor"]),
            cursorColor: getThemeValue(
                at: ["DVTSourceTextInsertionPointColor"]),
            currentLineColor: getThemeValue(
                at: ["DVTSourceTextCurrentLineHighlightColor"]),
            invisibleCharactersColor: getThemeValue(
                at: ["DVTSourceTextInvisiblesColor"]),
            debuggerConsolePromptColor: getThemeValue(
                at: ["DVTConsoleDebuggerPromptTextColor"]),
            debuggerConsoleOutputColor: getThemeValue(
                at: ["DVTConsoleDebuggerOutputTextColor"]),
            debuggerConsoleInputColor: getThemeValue(
                at: ["DVTConsoleDebuggerInputTextColor"]),
            executableConsoleOutputColor: getThemeValue(
                at: ["DVTConsoleExectuableOutputTextColor"]),
            executableConsoleInputColor: getThemeValue(
                at: ["DVTConsoleExectuableInputTextColor"])
        )

        return xcodeTheme
    }
}

extension XcodeTheme.ThemeColor {
    public func nsColor(windowColorSpace: NSColorSpace) -> NSColor {
        let generic = NSColor(colorSpace: .genericRGB, components: [red, green, blue, alpha], count: 4)
        return generic.usingColorSpace(windowColorSpace) ?? generic
    }
}

// MARK: - HighlightJS CSS Theme Builder

extension XcodeTheme {
    /// Builds a highlight.js CSS theme string from this Xcode theme.
    /// This maps Xcode syntax colors to highlight.js CSS classes.
    public func buildHighlightJSCSS() -> String {
        // Use fallback colors if specific colors are missing
        let plainText = plainTextColor?.hexString ?? "#000000D8"
        let background = backgroundColor?.hexString ?? "#FFFFFFFF"
        let comment = commentColor?.hexString ?? plainText
        let keyword = keywordsColor?.hexString ?? plainText
        let string = stringsColor?.hexString ?? plainText
        let number = numbersColor?.hexString ?? plainText
        let attribute = attributesColor?.hexString ?? plainText
        let typeDecl = typeDeclarationsColor?.hexString ?? plainText
        let otherDecl = otherDeclarationsColor?.hexString ?? plainText
        let otherType = otherTypeNamesColor?.hexString ?? plainText
        let otherProps = otherPropertiesAndGlobalsColor?.hexString ?? plainText
        let regex = regexLiteralsColor?.hexString ?? plainText
        let url = urlsColor?.hexString ?? plainText
        let heading = headingColor?.hexString ?? plainText
        let marks = marksColor?.hexString ?? plainText
        let selection = selectionColor?.hexString ?? "#A3CCFEFF"

        // swiftformat:disable all
        return """
        .hljs {
          display: block;
          overflow-x: auto;
          padding: 0.5em;
          background: \(background);
          color: \(plainText);
        }
        .xml .hljs-meta {
          color: \(marks);
        }
        .hljs-comment,
        .hljs-quote {
          color: \(comment);
        }
        .hljs-tag,
        .hljs-keyword,
        .hljs-selector-tag,
        .hljs-literal,
        .hljs-name {
          color: \(keyword);
        }
        .hljs-attribute {
          color: \(attribute);
        }
        .hljs-variable,
        .hljs-template-variable {
          color: \(otherProps);
        }
        .hljs-code,
        .hljs-string,
        .hljs-meta-string {
          color: \(string);
        }
        .hljs-regexp {
          color: \(regex);
        }
        .hljs-link {
          color: \(url);
        }
        .hljs-title {
          color: \(heading);
        }
        .hljs-symbol,
        .hljs-bullet {
          color: \(attribute);
        }
        .hljs-number {
          color: \(number);
        }
        .hljs-section {
          color: \(marks);
        }
        .hljs-meta {
          color: \(keyword);
        }
        .hljs-type,
        .hljs-built_in,
        .hljs-builtin-name {
          color: \(otherType);
        }
        .hljs-class .hljs-title,
        .hljs-title .class_ {
          color: \(typeDecl);
        }
        .hljs-function .hljs-title,
        .hljs-title .function_ {
          color: \(otherDecl);
        }
        .hljs-params {
          color: \(otherDecl);
        }
        .hljs-attr {
          color: \(attribute);
        }
        .hljs-subst {
          color: \(plainText);
        }
        .hljs-formula {
          background-color: \(selection);
          font-style: italic;
        }
        .hljs-addition {
          background-color: #baeeba;
        }
        .hljs-deletion {
          background-color: #ffc8bd;
        }
        .hljs-selector-id,
        .hljs-selector-class {
          color: \(plainText);
        }
        .hljs-doctag,
        .hljs-strong {
          font-weight: bold;
        }
        .hljs-emphasis {
          font-style: italic;
        }
        """
        // swiftformat:enable all
    }
}
