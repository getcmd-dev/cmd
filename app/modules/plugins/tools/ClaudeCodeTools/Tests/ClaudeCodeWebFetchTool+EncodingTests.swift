// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing

@testable import ClaudeCodeTools

@Suite("ClaudeCodeWebFetchTool Encoding Tests")
struct ClaudeCodeWebFetchToolEncodingTests {

  @Test("Input encoding and decoding")
  func testInputEncodingDecoding() throws {
    let input = ClaudeCodeWebFetchTool.Use.Input(
      url: "https://www.example.com/page?query=test&lang=en",
      prompt: "Extract all the headings and summarize the main points")

    let encoder = JSONEncoder()
    let data = try encoder.encode(input)

    let decoder = JSONDecoder()
    let decodedInput = try decoder.decode(ClaudeCodeWebFetchTool.Use.Input.self, from: data)

    #expect(decodedInput.url == input.url)
    #expect(decodedInput.prompt == input.prompt)
  }

  @Test("Output encoding and decoding")
  func testOutputEncodingDecoding() throws {
    let output = ClaudeCodeWebFetchTool.Use.Output(
      result: """
        The page contains the following headings:
        - Introduction to Web Development
        - Getting Started with HTML
        - CSS Fundamentals

        Main points:
        1. Web development involves creating websites and web applications
        2. HTML provides structure, CSS provides styling
        3. JavaScript adds interactivity
        """)

    let encoder = JSONEncoder()
    let data = try encoder.encode(output)

    let decoder = JSONDecoder()
    let decodedOutput = try decoder.decode(ClaudeCodeWebFetchTool.Use.Output.self, from: data)

    #expect(decodedOutput.result == output.result)
  }

  @Test("Input JSON structure")
  func testInputJSONStructure() throws {
    let input = ClaudeCodeWebFetchTool.Use.Input(
      url: "https://api.example.com/v1/data",
      prompt: "What is the API response format?")

    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let data = try encoder.encode(input)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["url"] as? String == "https://api.example.com/v1/data")
    #expect(json?["prompt"] as? String == "What is the API response format?")
    #expect(json?.count == 2)
  }

  @Test("Output JSON structure")
  func testOutputJSONStructure() throws {
    let output = ClaudeCodeWebFetchTool.Use.Output(
      result: "The API returns JSON with status and data fields")

    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let data = try encoder.encode(output)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(json?["result"] as? String == "The API returns JSON with status and data fields")
    #expect(json?.count == 1)
  }

  @Test("Special characters in input")
  func testSpecialCharactersInInput() throws {
    let input = ClaudeCodeWebFetchTool.Use.Input(
      url: "https://example.com/search?q=swift+6.0&filter=latest#results",
      prompt: "Find information about \"Swift 6.0\" features & improvements\n\nFocus on: async/await")

    let encoder = JSONEncoder()
    let data = try encoder.encode(input)

    let decoder = JSONDecoder()
    let decodedInput = try decoder.decode(ClaudeCodeWebFetchTool.Use.Input.self, from: data)

    #expect(decodedInput.url == input.url)
    #expect(decodedInput.prompt == input.prompt)
  }

  @Test("Long content in output")
  func testLongContentInOutput() throws {
    let longResult = String(repeating: "This is a long piece of content. ", count: 100)
    let output = ClaudeCodeWebFetchTool.Use.Output(result: longResult)

    let encoder = JSONEncoder()
    let data = try encoder.encode(output)

    let decoder = JSONDecoder()
    let decodedOutput = try decoder.decode(ClaudeCodeWebFetchTool.Use.Output.self, from: data)

    #expect(decodedOutput.result == output.result)
    #expect(decodedOutput.result.count == longResult.count)
  }
}
