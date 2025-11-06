// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppKit
import Foundation
import Testing
@testable import FileDiffFoundation

@Suite("Git diff generation")
struct GetGitDiffTests {
  @Suite("Line-level diffs")
  struct LineLevelDiffTests {
    @Test("With no changes")
    func test_gitDiffWithNoChanges() async throws {
      let oldContent = """
        static func shell(_ command: String) -> String {
          let task = Process()
          let pipe = Pipe()

          task.standardOutput = pipe
          task.standardError = pipe
          task.arguments = ["-c", command]
          task.launchPath = "/bin/bashrc"
          task.standardInput = nil
          task.launch()

          let data = pipe.fileHandleForReading.readDataToEndOfFile()
          return String(data: data, encoding: .utf8)!
        }
        """
      let newContent = """
        /// Run a shell command and return the output as a string.
        /// Doesn't handle errors.
        static func shell(_ command: String) -> String {
          let task = Process()
          let pipe = Pipe()

          task.standardOutput = pipe
          task.standardError = pipe
          task.arguments = ["-c", command]
          task.launchPath = "/bin/zsh"
          task.standardInput = nil
          task.launch()

          let data = pipe.fileHandleForReading.readDataToEndOfFile()
          return String(data: data, encoding: .utf8)!
        }
        """
      let gitDiff = try FileDiff.getGitDiff(oldContent: oldContent, newContent: newContent)
      #expect(
        gitDiff.trimmingCharacters(in: .whitespacesAndNewlines) == """
          @@ -1,3 +1,5 @@
          +/// Run a shell command and return the output as a string.
          +/// Doesn\'t handle errors.
           static func shell(_ command: String) -> String {
             let task = Process()
             let pipe = Pipe()
          @@ -5,7 +7,7 @@ static func shell(_ command: String) -> String {
             task.standardOutput = pipe
             task.standardError = pipe
             task.arguments = [\"-c\", command]
          -  task.launchPath = \"/bin/bashrc\"
          +  task.launchPath = \"/bin/zsh\"
             task.standardInput = nil
             task.launch()
          """)
    }

    @Test("Git diff with multiple changes")
    func test_gitDiffWithMultipleChanges() async throws {
      let oldContent = """
        func hello() {
          print("Hello")
          return
        }
        """
      let newContent = """
        func hello(name: String) {
          print("Hello \\(name)!")
        }
        """

      let gitDiff = try FileDiff.getGitDiff(oldContent: oldContent, newContent: newContent)
      #expect(gitDiff.contains("-  print(\"Hello\")"))
      #expect(gitDiff.contains("+  print(\"Hello \\(name)!\")"))
    }

    @Test("With empty content")
    func test_gitDiffWithEmptyContent() async throws {
      let oldContent = ""
      let newContent = "Hello World"

      let gitDiff = try FileDiff.getGitDiff(oldContent: oldContent, newContent: newContent)
      #expect(gitDiff.contains("+Hello World"))
    }
  }

  @Suite("Character-level diffs")
  struct CharacterLevelDiffTests {
    @Test("Simple word replacement")
    func simpleWordReplacement() throws {
      let oldContent = "Hello World"
      let newContent = "Hello Swift"

      let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)

      #expect(
        diff == """
          @@ -1 +1 @@
          Hello [-World-]{+Swift+}
          """)
    }

    @Test("Addition only")
    func additionOnly() throws {
      let oldContent = "Hello"
      let newContent = "Hello World"

      let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)

      #expect(
        diff == """
          @@ -1 +1 @@
          Hello{+ World+}
          """)
    }

    @Test("Removal only")
    func removalOnly() throws {
      let oldContent = "Hello World"
      let newContent = "Hello"

      let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)

      #expect(
        diff == """
          @@ -1 +1 @@
          Hello[- World-]
          """)
    }

    @Test("Empty to content")
    func emptyToContent() throws {
      let oldContent = ""
      let newContent = "Hello"

      let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)

      #expect(
        diff == """
          @@ -0,0 +1 @@
          {+Hello+}
          """)
    }

    @Test("Character in middle of word")
    func characterInMiddleOfWord() throws {
      let oldContent = "Helo"
      let newContent = "Hello"

      let diff = try FileDiff.getCharacterDiff(oldContent: oldContent, newContent: newContent)

      #expect(
        diff == """
          @@ -1 +1 @@
          Hel{+l+}o
          """)
    }
  }
}
