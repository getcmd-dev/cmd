// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import FileDiffTypesFoundation
import Foundation

// MARK: - FileChangeDiff

/// Represents a set of changes for one file.
public struct FileChangeDiff: Sendable, Codable {
  /// The previous content of the file.
  public let oldContent: String
  /// The new content of the file.
  public let newContent: String
  /// Those ranges describe how a diff representation (ie a combination of unchanged, added and removed lines) can be generated from the previous content to the new content.
  /// Each entry describes whether a line should be removed/kept/added.
  public let diff: [LineChange]

  public init(oldContent: String, newContent: String, diff: [LineChange]) {
    self.oldContent = oldContent
    self.newContent = newContent
    self.diff = diff
  }
}

extension FileDiff {

  /// A structure representing a search and replace operation
  public struct SearchReplace: Sendable {
    /// The text to search for
    public let search: String.SubSequence
    /// The text to replace it with
    public let replace: String.SubSequence

    public init(search: String.SubSequence, replace: String.SubSequence) {
      self.search = search
      self.replace = replace
    }

    public init(search: String, replace: String) {
      self.search = search[...]
      self.replace = replace[...]
    }
  }

  /// Creates a FileChangeDiff by parsing an input that contains search/replace blocks and applying them to the given content
  ///
  /// - Parameters:
  ///   - searchReplacePattern: A string containing search/replace blocks in the format:
  ///     <<<<<<< SEARCH
  ///     // Search text
  ///     =======
  ///     // Replacement text
  ///     >>>>>>> REPLACE
  ///   - content: The original file content to apply the changes to
  /// - Returns: A FileChangeDiff representing the changes made
  public static func getFileChange(applying searchReplacePattern: String, to content: String) throws -> FileChangeDiff {
    let changes = try parse(searchReplacePattern: searchReplacePattern, for: content)
    let newContent: String = try apply(changes: changes, to: content)
    return try getFileChange(changing: content, to: newContent)
  }

  /// Creates a FileChangeDiff by applying an array of search/replace operations to the given content
  ///
  /// - Parameters:
  ///   - changes: An array of search/replace pairs to apply
  ///   - content: The original file content to apply the changes to
  /// - Returns: A FileChangeDiff representing the changes made
  public static func getFileChange(applying changes: [SearchReplace], to content: String) throws -> FileChangeDiff {
    let newContent: String = try apply(changes: changes, to: content)
    return try getFileChange(changing: content, to: newContent)
  }

  public static func getFileChange(changing content: String, to newContent: String) throws -> FileChangeDiff {
    let gitDiff = try getGitDiff(oldContent: content, newContent: newContent)
    let changedRanges = gitDiffToChangedRanges(oldContent: content, newContent: newContent, diffText: gitDiff)
    return FileChangeDiff(oldContent: content, newContent: newContent, diff: changedRanges)
  }

  /// Returns whether the string is in the diff format we expect to receive from an LLM.
  public static func isLLMDiff(_ maybeDiff: String) -> Bool {
    // Check if there is any unparsed diff
    let unparsedDiff = maybeDiff.replacing(llmDiffRegex, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    return unparsedDiff.isEmpty
  }

  /// Parses a string that contains one or several search/replace blocks and returns an array of SearchReplace objects.
  ///
  /// The diff string should contain line markers in the format corresponding to the `withDiffMarkersForLLM` method.
  /// Changed line positions can be marked as modified with "// modified" or deleted with "// deleted".
  /// New lines should not contain any markers.
  ///
  /// - Parameters:
  ///   - diff: The LLM-generated diff string containing line markers and modifications
  ///   - fileContent: The original file content to apply the diff to
  public static func parse(searchReplacePattern diff: String, for fileContent: String) throws -> [SearchReplace] {
    if diff.isEmpty {
      return []
    }
    if !isLLMDiff(diff) {
      throw DiffError.notADiff(content: diff)
    }

    return try diff.matches(of: llmDiffRegex).map { match in
      var search = match.output.search
      var replace = match.output.replace

      // As the search/replace format is not precise on whether it is matching new lines at the beginning/end
      // (there should either be a new line or the beginning/end of the file)
      // we go through each case in order.
      if !search.hasSuffix("\n") {
        // Given the regex, this can only happen if the search is empty, which is only allowed if the file content is empty.
        assert(search.isEmpty)
        if !fileContent.isEmpty {
          throw DiffError.message("Search pattern -\(search)- does not end with a newline character.")
        }
      } else {
        search.removeLast()

        if fileContent == search {
          // First try to match the whole file
//            firstFind = result.startIndex
          if replace.hasSuffix("\n") {
            replace.removeLast()
          }
//              return SearchReplace(search: search, replace: replace)
        } else if fileContent.hasPrefix(search + "\n") {
          // Then try to match the beginning of the file
//            firstFind = fileContent.startIndex
          search = search + "\n"
        } else if fileContent.index(of: "\n" + search + "\n") != nil {
          // Then try to match a line in the middle of the file
//            firstFind = result.index(after: middleMatch)
          search = search + "\n"
        } else if fileContent.hasSuffix("\n" + search) {
          // Finally try to match the end of a file with no trailing new line.
//            firstFind = fileContent.index(fileContent.endIndex, offsetBy: -search.count - 1)
          search = "\n" + search
          replace = "\n" + replace
          if replace.hasSuffix("\n") {
            replace.removeLast()
          }
        }
      }
      return SearchReplace(search: search, replace: replace)
    }
  }

  /// Applies a diff string generated by an LLM to the given file content.
  ///
  /// The diff string should contain line markers in the format corresponding to the `withDiffMarkersForLLM` method.
  /// Changed line positions can be marked as modified with "// modified" or deleted with "// deleted".
  /// New lines should not contain any markers.
  ///
  /// - Parameters:
  ///   - diff: The LLM-generated diff string containing line markers and modifications
  ///   - fileContent: The original file content to apply the diff to
  /// - Returns: The modified file content with the diff applied
  public static func apply(changes: [SearchReplace], to fileContent: String) throws -> String {
    if changes.isEmpty {
      return fileContent
    }

    var result = fileContent

    for change in changes {
      let search = change.search
      let replace = change.replace

      let firstFind: String.Index? =
        if search == "" {
          result.startIndex
        } else {
          result.index(of: search)
        }

      guard let firstFind else {
        throw DiffError.message("Could not find search pattern in original content:\n---\n\(search)\n---")
      }

      let startIndex = firstFind
      let endIndex = result.index(firstFind, offsetBy: search.count)

      // Replace the search text with the replacement text (which might be empty for deletions)
      result.replaceSubrange(startIndex..<endIndex, with: replace)
    }

    // Remove any leading newlines that might have been introduced when deleting the first line
    if result.hasPrefix("\n") {
      result.removeFirst()
    }

    return result
  }

  /// Regex breakdown:
  /// <<<<<<< SEARCH\n - Matches the literal start marker followed by a newline
  /// (?<search> - Named capture group "search" that will store the content to find
  ///   ([\s\S]*?\n)? - Group that matches:
  ///     [\s\S]*? - Any character (whitespace \s or non-whitespace \S), any number of times (*)
  ///                The ? after + makes it non-greedy, matching as few characters as possible
  ///     \n - Followed by a newline
  ///     )? - The entire group is optional (matches 0 or 1 times)
  /// =======\n - Matches the literal separator followed by a newline
  /// (?<replace> - Named capture group "replace" that will store the replacement content
  ///   ([\s\S]*?\n)? - Same pattern as in the search group: any characters (non-greedy) + newline, optional
  /// >>>>>>> REPLACE - Matches the literal end marker
  private static let llmDiffRegex = /<<<<<<< SEARCH\n(?<search>([\s\S]*?\n)?)=======\n(?<replace>([\s\S]*?\n)?)>>>>>>> REPLACE/

}

// MARK: - DiffError

public enum DiffError: Error, LocalizedError {
  case message(String)
  case notADiff(content: String)

  public var errorDescription: String? {
    switch self {
    case .message(let message):
      message
    case .notADiff(let content):
      "The diff is not correctly formatted. Could not parse \(content)"
    }
  }
}

extension StringProtocol {
  func index(of string: some StringProtocol, options: String.CompareOptions = []) -> Index? {
    range(of: string, options: options)?.lowerBound
  }

  func endIndex(of string: some StringProtocol, options: String.CompareOptions = []) -> Index? {
    range(of: string, options: options)?.upperBound
  }

  func indices(of string: some StringProtocol, options: String.CompareOptions = []) -> [Index] {
    ranges(of: string, options: options).map(\.lowerBound)
  }

  func ranges(of string: some StringProtocol, options: String.CompareOptions = []) -> [Range<Index>] {
    var result: [Range<Index>] = []
    var startIndex = startIndex
    while
      startIndex < endIndex,
      let range = self[startIndex...]
        .range(of: string, options: options)
    {
      result.append(range)
      startIndex = range.lowerBound < range.upperBound
        ? range.upperBound
        : index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
    }
    return result
  }
}

extension Regex: @unchecked @retroactive Sendable { }
