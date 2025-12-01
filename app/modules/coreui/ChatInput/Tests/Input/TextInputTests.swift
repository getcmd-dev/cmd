// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import Foundation
import SwiftTesting
import Testing
@testable import ChatInput

struct TextInputTests {

  @Test("initialization with empty elements")
  func test_initialization_withEmptyElements() {
    let textInput = TextInput()

    #expect(textInput.elements.isEmpty)
    #expect(textInput.isEmpty)
  }

  @Test("initialization with elements")
  func test_initialization_withElements() throws {
    let elements: [TextInput.Element] = [
      .text("Hello"),
      .reference(TextInput.Reference(display: "@file.swift", id: "123")),
      .text(" world"),
    ]

    let textInput = TextInput(elements)

    #expect(textInput.elements.count == 3)
    #expect(!textInput.isEmpty)

    #expect(textInput.elements[0].text == "Hello")

    let reference = try #require(textInput.elements[1].reference)
    #expect(reference.display == "@file.swift")
    #expect(reference.id == "123")

    #expect(textInput.elements[2].text == " world")
  }

  @Test("appending text to empty input")
  func test_appendingText_toEmptyInput() throws {
    var textInput = TextInput()

    textInput.append("Hello")

    #expect(textInput.elements.count == 1)
    #expect(textInput.elements[0].text == "Hello")
  }

  @Test("appending text to existing text")
  func test_appendingText_toExistingText() throws {
    var textInput = TextInput([.text("Hello")])

    textInput.append(", world!")

    #expect(textInput.elements.count == 1)
    #expect(textInput.elements[0].text == "Hello, world!")
  }

  @Test("appending text after reference")
  func test_appendingText_afterReference() throws {
    var textInput = TextInput([
      .reference(TextInput.Reference(display: "@file.swift", id: "123")),
    ])

    textInput.append(" Hello")

    #expect(textInput.elements.count == 2)

    let reference = try #require(textInput.elements[0].reference)
    #expect(reference.display == "@file.swift")
    #expect(reference.id == "123")

    #expect(textInput.elements[1].text == " Hello")
  }

  @Test("reference equality")
  func test_referenceEquality() {
    let reference1 = TextInput.Reference(display: "@file.swift", id: "123")
    let reference2 = TextInput.Reference(display: "@file.swift", id: "123")
    let reference3 = TextInput.Reference(display: "@other.swift", id: "123")
    let reference4 = TextInput.Reference(display: "@file.swift", id: "456")

    #expect(reference1 == reference2)
    #expect(reference1 != reference3)
    #expect(reference1 != reference4)
  }

  @Test("initializing TextInput from attributed string")
  func test_initializingTextInput_fromAttributedString() {
    // Create a simple attributed string
    let attributedString = NSAttributedString(string: "Hello, world!")

    let textInput = TextInput(attributedString)

    #expect(textInput.elements.count == 1)
    #expect(textInput.elements[0].text == "Hello, world!")
  }

  @Test("initializing TextInput from attributed string with reference")
  func test_initializingTextInput_fromAttributedStringWithReference() throws {
    // Create an attributed string with a reference
    let reference = TextInput.Reference(display: "@file.swift", id: "123")
    let referenceString = reference.asReferenceBlock

    let combinedString = NSMutableAttributedString(string: "Hello ")
    combinedString.append(referenceString)
    combinedString.append(NSAttributedString(string: " world!"))

    let combinedTextInput = TextInput(combinedString)

    #expect(combinedTextInput.elements.count == 3)

    #expect(combinedTextInput.elements[0].text == "Hello ")

    let extractedReference = try #require(combinedTextInput.elements[1].reference)
    #expect(extractedReference.display == "@file.swift")
    #expect(extractedReference.id == "123")

    #expect(combinedTextInput.elements[2].text == " world!")
  }
}
