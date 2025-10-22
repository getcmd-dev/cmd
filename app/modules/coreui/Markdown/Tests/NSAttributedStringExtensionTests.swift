// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import Foundation
import Testing

@testable import Markdown

// MARK: - NSAttributedStringExtensionTests

@MainActor
struct NSAttributedStringExtensionTests {

  @Test("trim whitespace and newlines at the beginning and end")
  func test_trimWhitespaceAndNewlines() throws {
    // Create an attributed string with whitespace and newlines at beginning and end
    let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.red]
    let original = NSAttributedString(
      string: "\n  Hello World  \n",
      attributes: attributes)

    // Apply the trimming method
    let trimmed = original.trimmedAttributedString()

    // Check trimmed string value
    #expect(trimmed.string == "Hello World")

    // Ensure attributes are preserved
    let expectedAttributes = trimmed.attributes(at: 0, effectiveRange: nil)
    #expect(expectedAttributes[.foregroundColor] as? NSColor == NSColor.red)
  }

  @Test("trim only beginning whitespace")
  func test_trimBeginningWhitespace() throws {
    let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.blue]
    let original = NSAttributedString(
      string: "   Hello World",
      attributes: attributes)

    let trimmed = original.trimmedAttributedString()

    #expect(trimmed.string == "Hello World")
    #expect(trimmed.attributes(at: 0, effectiveRange: nil)[.foregroundColor] as? NSColor == NSColor.blue)
  }

  @Test("trim only ending whitespace")
  func test_trimEndingWhitespace() throws {
    let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.green]
    let original = NSAttributedString(
      string: "Hello World \n\n",
      attributes: attributes)

    let trimmed = original.trimmedAttributedString()

    #expect(trimmed.string == "Hello World")
    #expect(trimmed.attributes(at: 0, effectiveRange: nil)[.foregroundColor] as? NSColor == NSColor.green)
  }

  @Test("Non trimmable string returns self")
  func test_emptyString() throws {
    let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.yellow]
    let original = NSAttributedString(
      string: "hello",
      attributes: attributes)

    let trimmed = original.trimmedAttributedString()

    #expect(trimmed === original) // Test reference equality - should be the same instance
  }

  @Test("string with only whitespace returns empty string")
  func test_onlyWhitespace() throws {
    let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.yellow]
    let original = NSAttributedString(
      string: "  \n\t \n",
      attributes: attributes)

    let trimmed = original.trimmedAttributedString()

    #expect(trimmed.string == "")
  }

  @Test("string with mixed attributes maintains correct attributes")
  func test_mixedAttributes() throws {
    // Create an attributed string with multiple attributes
    let mutableString = NSMutableAttributedString()

    // Add whitespace at the beginning with one attribute
    let prefix = NSAttributedString(
      string: "  \n",
      attributes: [.foregroundColor: NSColor.gray])
    mutableString.append(prefix)

    // Add main content with different attribute
    let content = NSAttributedString(
      string: "Hello World",
      attributes: [.foregroundColor: NSColor.black, .font: NSFont.systemFont(ofSize: 14)])
    mutableString.append(content)

    // Add whitespace at the end with a third attribute
    let suffix = NSAttributedString(
      string: "\n  ",
      attributes: [.foregroundColor: NSColor.gray])
    mutableString.append(suffix)

    // Trim and test
    let trimmed = mutableString.trimmedAttributedString()

    // Should contain only the middle part with its attributes
    #expect(trimmed.string == "Hello World")

    // Check attributes of the trimmed string
    var effectiveRange = NSRange()
    let attrs = trimmed.attributes(at: 0, effectiveRange: &effectiveRange)

    #expect(effectiveRange.location == 0)
    #expect(effectiveRange.length == trimmed.length)
    #expect(attrs[.foregroundColor] as? NSColor == NSColor.black)
    #expect(attrs[.font] as? NSFont == NSFont.systemFont(ofSize: 14))
  }
}
