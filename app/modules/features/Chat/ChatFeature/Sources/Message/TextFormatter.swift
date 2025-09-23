// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import HighlightSwift
import Observation

// MARK: - TextFormatter

@Observable @MainActor
final class TextFormatter {

  init(projectRoot: URL?) {
    self.projectRoot = projectRoot
    text = ""
    deltas = []
  }

  enum Element: Identifiable {
    case text(_ text: TextElement)
    case codeBlock(_ code: CodeBlockElement)

    @Observable @MainActor
    class TextElement {

      init(text: String, isComplete: Bool, id: Int) {
        self.id = id
        _text = text.trimmed(isComplete: isComplete)
        self.isComplete = isComplete
      }

      let id: Int
      var isComplete: Bool

      var text: String {
        get { _text }
        set { _text = newValue.trimmed(isComplete: isComplete) }
      }

      private var _text: String
    }

    typealias CodeBlockElement = ChatFeature.CodeBlockElement

    var id: Int {
      switch self {
      case .text(let text): text.id
      case .codeBlock(let code): code.id
      }
    }

    var asText: TextElement? {
      if case .text(let text) = self {
        return text
      }
      return nil
    }

    var asCodeBlock: CodeBlockElement? {
      if case .codeBlock(let code) = self {
        return code
      }
      return nil
    }

  }

  private(set) var text: String

  private(set) var elements = [Element]()

  private(set) var deltas: [String]

  let projectRoot: URL?

  func catchUp(deltas: [String]) {
    guard deltas.count > self.deltas.count else { return }
    for delta in deltas.suffix(from: self.deltas.count) {
      ingest(delta: delta)
    }
    self.deltas = deltas
  }

  /// Processes a new delta (incremental update) of text
  /// - Parameter delta: The new text fragment to process
  /// - Note: This method handles both regular text and code block formatting
  func ingest(delta: String) {
    deltas.append(delta)
    unconsumed = "\(unconsumed)\(delta)"
    processUnconsumedText()
  }

  private var unconsumed = ""
  private var isEscaping = false
  private var isCodeBlockHeader = false

  private func processUnconsumedText() {
    var backtickCount = 0

    var i = 0
    var canConsummedUntil = 0
    for c in unconsumed {
      i += 1
      if handleBackticks(c: c, i: &i, backtickCount: &backtickCount, canConsummedUntil: &canConsummedUntil) { continue }
      backtickCount = 0
      if handleEscaping(c: c, backtickCount: &backtickCount) { continue }
      isEscaping = false
      if c == "\n", isCodeBlockHeader {
        handleCodeBlockHeader(i: &i, canConsummedUntil: &canConsummedUntil)
      }
      if isCodeBlockHeader {
        continue
      }
      if c != " ", c != "\n", c != "\r", c != "\t" {
        // The current character can be appended to the last element.
        // Don't make more expensive modification to the state now, just track the offset.
        canConsummedUntil = i
      } else {
        // For whitespaces, wait for more content to know if we'll show it or trim it.
      }
    }

    consumeUntil(canConsummedUntil: canConsummedUntil)
  }

  private func handleEscaping(c: Character, backtickCount: inout Int) -> Bool {
    guard c == #"\"# else { return false }
    isEscaping = !isEscaping
    backtickCount = 0
    return true
  }

  private func handleBackticks(c: Character, i: inout Int, backtickCount: inout Int, canConsummedUntil: inout Int) -> Bool {
    guard c == "`" else { return false }
    guard !isEscaping else {
      isEscaping = false
      return true
    }

    backtickCount += 1
    if backtickCount == 3 {
      backtickCount = 0
      if let codeBlock = elements.last?.asCodeBlock, !codeBlock.isComplete {
        // close the code bock
        var newCode = unconsumed.prefix(i)
        unconsumed.removeFirst(i)
        i = 0
        canConsummedUntil = 0
        // Drop the delimiter (```)
        newCode.removeLast(3)
        add(code: "\(codeBlock.rawContent)\(newCode)", isComplete: true, at: elements.count - 1)
      } else {
        // create a new code block
        var newText = unconsumed.prefix(i)
        unconsumed.removeFirst(i)
        i = 0
        canConsummedUntil = 0
        // Drop the delimiter (```)
        newText.removeLast(3)

        if let text = elements.last?.asText {
          add(text: "\(text.text)\(newText)", isComplete: true, at: elements.count - 1)
        } else {
          if !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            add(text: "\(newText)", isComplete: true)
          }
        }
        add(code: "", isComplete: false)
        isCodeBlockHeader = true
      }
    }
    return true
  }

  private func handleCodeBlockHeader(i: inout Int, canConsummedUntil: inout Int) {
    let header = unconsumed.prefix(i).trimmingCharacters(in: .whitespacesAndNewlines)
    isCodeBlockHeader = false
    unconsumed.removeFirst(i)
    i = 0
    canConsummedUntil = 0

    guard let currentCodeBlock = elements.last?.asCodeBlock else {
      assertionFailure("No code block found when parsing code block header")
      return
    }

    // Parse the language and file path out of the header.
    if let match = header.firstMatch(of: /^(?<language>\w+):(?<path>.*)$/) {
      let language = match.output.language
      let path = match.output.path
      currentCodeBlock.language = String(language)
      currentCodeBlock.filePath = String(path)
    } else if let language = HighlightLanguage(rawValue: header) {
      currentCodeBlock.language = language.rawValue
    } else if !header.isEmpty {
      currentCodeBlock.filePath = header
    }
  }

  private func consumeUntil(canConsummedUntil: Int) {
    if canConsummedUntil > 0 {
      let consumed = unconsumed.prefix(canConsummedUntil)
      unconsumed.removeFirst(canConsummedUntil)
      if let lastElement = elements.last {
        switch lastElement {
        case .text(let text):
          add(text: "\(text.text)\(consumed)", isComplete: false, at: elements.count - 1)
          return

        case .codeBlock(let codeBlock):
          if !codeBlock.isComplete {
            add(code: "\(codeBlock.rawContent)\(consumed)", isComplete: false, at: elements.count - 1)
            return
          }
        }
      }
      if !consumed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        add(text: "\(consumed)", isComplete: false)
      }
    }
  }

  private func add(text: String, isComplete: Bool, at idx: Int? = nil) {
    let id = idx ?? elements.count
    if id == elements.count {
      elements.append(Element.text(.init(text: text, isComplete: isComplete, id: id)))
    } else {
      let element = elements[id].asText
      element?.isComplete = isComplete
      element?.text = text
    }
  }

  private func add(code: String, isComplete: Bool, at idx: Int? = nil) {
    let id = idx ?? elements.count
    if id == elements.count {
      elements.append(Element.codeBlock(.init(projectRoot: projectRoot, rawContent: code, isComplete: isComplete, id: id)))
    } else {
      let element = elements[id].asCodeBlock
      element?.set(rawContent: code, isComplete: isComplete)
    }
  }

}

extension String {

  func trimmed(isComplete: Bool) -> String {
    isComplete
      ? trimmingCharacters(in: .whitespacesAndNewlines)
      : trimmingLeadingCharacters(in: .whitespacesAndNewlines)
  }

  private func trimmingLeadingCharacters(in characterSet: CharacterSet) -> String {
    guard let index = firstIndex(where: { !CharacterSet(charactersIn: String($0)).isSubset(of: characterSet) }) else {
      return self
    }
    return String(self[index...])
  }

}
