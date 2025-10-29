// swiftformat:disable all

// Copied from https://github.com/github/CopilotForXcode/blob/d76757f2c1d263cefcecab7a96c61eac234d21c4/Tool/Sources/WebContentExtractor/HTMLToMarkdownConverter.swift

import SwiftSoup
import WebKit

class HTMLToMarkdownConverter {

  // MARK: - Main Conversion Method
  func convertToMarkdown(from html: String) throws -> String {
    let doc = try SwiftSoup.parse(html)
    let rawMarkdown = try extractCleanContent(from: doc)
    return cleanupExcessiveNewlines(rawMarkdown)
  }

  func convertElement(_ element: Element) throws -> String {
    var result = ""

    for node in element.getChildNodes() {
      if let textNode = node as? TextNode {
        result += textNode.text()
      } else if let childElement = node as? Element {
        result += try convertSpecificElement(childElement)
      }
    }

    return result
  }

  // MARK: - Configuration
  private enum Config {
    static let unwantedSelectors = "script, style, nav, header, footer, aside, noscript, iframe, .navigation, .sidebar, .ad, .advertisement, .cookie-banner, .popup, .social, .share, .social-share, .related, .comments, .menu, .breadcrumb"
    static let mainContentSelectors = [
      "main",
      "article",
      "div.content",
      "div#content",
      "div.post-content",
      "div.article-body",
      "div.main-content",
      "section.content",
      ".content",
      ".main",
      ".main-content",
      ".article",
      ".article-content",
      ".post-content",
      "#content",
      "#main",
      ".container .row .col",
      "[role='main']",
    ]
  }

  // MARK: - Content Extraction
  private func extractCleanContent(from doc: Document) throws -> String {
    try removeUnwantedElements(from: doc)

    // Try to find main content areas
    for selector in Config.mainContentSelectors {
      if let mainElement = try findMainContent(in: doc, using: selector) {
        return try convertElementToMarkdown(mainElement)
      }
    }

    // Fallback: clean body content
    return try fallbackContentExtraction(from: doc)
  }

  private func removeUnwantedElements(from doc: Document) throws {
    try doc.select(Config.unwantedSelectors).remove()
  }

  private func findMainContent(in doc: Document, using selector: String) throws -> Element? {
    let elements = try doc.select(selector)
    guard let mainElement = elements.first() else { return nil }

    // Clean nested unwanted elements
    try mainElement.select("nav, aside, .related, .comments, .social-share, .advertisement").remove()
    return mainElement
  }

  private func fallbackContentExtraction(from doc: Document) throws -> String {
    guard let body = doc.body() else { return "" }
    try body.select(Config.unwantedSelectors).remove()
    return try convertElementToMarkdown(body)
  }

  // MARK: - Cleanup Method
  private func cleanupExcessiveNewlines(_ markdown: String) -> String {
    // Replace 3+ consecutive newlines with just 2 newlines
    let cleaned = markdown.replacingOccurrences(
      of: #"\n{3,}"#,
      with: "\n\n",
      options: .regularExpression)
    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // MARK: - Element Processing
  private func convertElementToMarkdown(_ element: Element) throws -> String {
    try convertElement(element)
  }

  private func convertSpecificElement(_ element: Element) throws -> String {
    let tagName = element.tagName().lowercased()
    let text = try element.text()

    switch tagName {
    case "h1":
      return "\n# \(text)\n"

    case "h2":
      return "\n## \(text)\n"

    case "h3":
      return "\n### \(text)\n"

    case "h4":
      return "\n#### \(text)\n"

    case "h5":
      return "\n##### \(text)\n"

    case "h6":
      return "\n###### \(text)\n"

    case "p":
      return try "\n\(convertElement(element))\n"

    case "br":
      return "\n"

    case "strong", "b":
      return "**\(text)**"

    case "em", "i":
      return "*\(text)*"

    case "code":
      return "`\(text)`"

    case "pre":
      return "\n```\n\(text)\n```\n"

    case "a":
      let href = try element.attr("href")
      let title = try element.attr("title")
      if href.isEmpty {
        return text
      }

      // Skip non-http/https/file schemes
      if
        let url = URL(string: href),
        let scheme = url.scheme?.lowercased(),
        !["http", "https", "file"].contains(scheme)
      {
        return text
      }

      let titlePart = title.isEmpty ? "" : " \"\(title.replacingOccurrences(of: "\"", with: "\\\""))\""
      return "[\(text)](\(href)\(titlePart))"

    case "img":
      let src = try element.attr("src")
      let alt = try element.attr("alt")
      let title = try element.attr("title")

      var finalSrc = src
      // Remove data URIs
      if src.hasPrefix("data:") {
        finalSrc = src.components(separatedBy: ",").first ?? "" + "..."
      }

      let titlePart = title.isEmpty ? "" : " \"\(title.replacingOccurrences(of: "\"", with: "\\\""))\""
      return "![\(alt)](\(finalSrc)\(titlePart))"

    case "ul":
      return try convertList(element, ordered: false)

    case "ol":
      return try convertList(element, ordered: true)

    case "li":
      return try convertElement(element)

    case "table":
      return try convertTable(element)

    case "blockquote":
      let content = try convertElement(element)
      return content.components(separatedBy: .newlines)
        .map { "> \($0)" }
        .joined(separator: "\n")

    default:
      return try convertElement(element)
    }
  }

  private func convertList(_ element: Element, ordered: Bool) throws -> String {
    var result = "\n"
    let items = try element.select("li")

    for (index, item) in items.enumerated() {
      let content = try convertElement(item).trimmingCharacters(in: .whitespacesAndNewlines)
      if ordered {
        result += "\(index + 1). \(content)\n"
      } else {
        result += "- \(content)\n"
      }
    }

    return result
  }

  private func convertTable(_ element: Element) throws -> String {
    var result = "\n"
    let rows = try element.select("tr")

    guard !rows.isEmpty() else { return "" }

    var isFirstRow = true
    for row in rows {
      let cells = try row.select("td, th")
      let cellContents = try cells.map { try $0.text() }

      result += "| " + cellContents.joined(separator: " | ") + " |\n"

      if isFirstRow {
        let separator = Array(repeating: "---", count: cellContents.count).joined(separator: " | ")
        result += "| \(separator) |\n"
        isFirstRow = false
      }
    }

    return result
  }
}
