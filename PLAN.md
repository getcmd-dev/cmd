# Plan: Adapt Syntax Highlighting for Code Completion

## Problem

The current `CompletionSyntaxHighlighter` highlights code snippets line-by-line, which doesn't work well because:
1. Syntax highlighting needs full context to correctly identify tokens (e.g., a keyword in isolation vs. part of a larger expression)
2. Highlighting each line separately leads to inconsistent coloring

## Solution Pattern (from `FileDiff+getColoredDiff.swift`)

The existing pattern for line diff highlighting:
1. Highlight the **entire** old content and new content as complete documents
2. Extract `AttributedSubstring` slices from the highlighted content for each line
3. Use character ranges to map each line's position in the full content

Key code from `FileDiff+getColoredDiff.swift`:
```swift
// Highlight entire contents in parallel
async let oldContentFormatting = highlighter.unTrimmedAttributedText(oldContent, language: .swift, colors: highlightColors)
async let newContentFormatting = highlighter.unTrimmedAttributedText(newContent, language: .swift, colors: highlightColors)

// Extract substrings for each line using character ranges
for lineChange in diffRanges {
  let formattedContent = lineChange.type == .removed ? oldContentFormatted : newContentFormatted
  guard let range = formattedContent.range(lineChange.characterRange) else { continue }
  let line = formattedContent[range]
  formattedLineChanges.append(FormattedLineChange(formattedContent: line, change: lineChange))
}
```

## Plan for `SyntaxHighlightedCompletion.swift`

### Step 1: Calculate character ranges for each line in the diff

We need to compute the character range (in either old or new content) for each change in the diff. The `diff` array contains `LineChange` items with `CharacterLevelChange` items, but we need absolute character positions in the full content.

Since `CompletionSuggestion` now has both `oldContent` and `newContent`, we can:
- For `.unchanged` and `.added` changes: extract from highlighted `newContent`
- For `.removed` changes: extract from highlighted `oldContent`

### Step 2: Highlight full old and new content (in parallel)

```swift
async let oldHighlighted = highlighter.unTrimmedAttributedText(completion.oldContent, language: language, colors: colors)
async let newHighlighted = highlighter.unTrimmedAttributedText(completion.newContent, language: language, colors: colors)
```

### Step 3: Build line-by-line highlighted content

For each line in the diff:
1. Iterate through the character changes
2. For each change, determine its character range in the appropriate content (old or new)
3. Extract the `AttributedSubstring` from the pre-highlighted content
4. Concatenate the substrings to build the highlighted line

### Step 4: Track character positions

Need to track:
- Position in old content (advances for `.unchanged` and `.removed`)
- Position in new content (advances for `.unchanged` and `.added`)

Starting position = `diffLineStart` converted to character offset.

### Performance Considerations

1. **Parallel highlighting**: Highlight old and new content concurrently using `async let`
2. **Single highlighting pass**: Each content is highlighted only once, not per-line
3. **Efficient range extraction**: Use pre-computed character offsets to extract substrings

## Implementation Changes

### `SyntaxHighlightedCompletion.swift`

Replace the current line-by-line highlighting with:

```swift
static func highlight(
  _ completion: CompletionSuggestion,
  xcodeTheme: XcodeTheme?)
  async -> SyntaxHighlightedCompletion?
{
  let colors = highlightColors(from: xcodeTheme)
  let language = language(for: completion.file)

  // Step 1: Highlight entire contents in parallel
  async let oldHighlightedTask = highlighter.unTrimmedAttributedText(
    completion.oldContent,
    language: language,
    colors: colors)
  async let newHighlightedTask = highlighter.unTrimmedAttributedText(
    completion.newContent,
    language: language,
    colors: colors)

  let (oldHighlighted, newHighlighted) = try await (oldHighlightedTask, newHighlightedTask)

  // Step 2: Compute starting character offsets
  let oldLines = completion.oldContent.splitLines()
  let newLines = completion.newContent.splitLines()
  let oldLineOffsets = computeLineOffsets(for: oldLines)
  let newLineOffsets = computeLineOffsets(for: newLines)

  var oldCharPos = oldLineOffsets[completion.diffLineStart]
  var newCharPos = newLineOffsets[completion.diffLineStart]

  // Step 3: Build highlighted lines by extracting from pre-highlighted content
  var highlightedLines = [SyntaxHighlightedCompletion.HighlightedLine]()

  for lineChange in completion.diff {
    var lineContent = AttributedString()
    var changes = [SyntaxHighlightedCompletion.HighlightedChange]()

    for change in lineChange.changes {
      let changeLength = change.text.count

      // Determine source content and position
      let (source, startPos) = switch change.type {
        case .removed: (oldHighlighted, oldCharPos)
        case .added, .unchanged: (newHighlighted, newCharPos)
      }

      // Extract attributed substring
      if let range = source.range(startPos..<(startPos + changeLength)) {
        let startIdx = lineContent.endIndex
        lineContent.append(AttributedString(source[range]))
        let endIdx = lineContent.endIndex

        changes.append(HighlightedChange(range: startIdx..<endIdx, type: change.type))
      }

      // Advance positions
      if change.type != .added { oldCharPos += changeLength }
      if change.type != .removed { newCharPos += changeLength }
    }

    highlightedLines.append(HighlightedLine(content: lineContent, changes: changes))
  }

  return SyntaxHighlightedCompletion(lines: highlightedLines)
}

private static func computeLineOffsets(for lines: [String.SubSequence]) -> [Int] {
  var offsets = [Int]()
  var offset = 0
  for line in lines {
    offsets.append(offset)
    offset += line.count
  }
  offsets.append(offset)
  return offsets
}
```

## Files to Modify

1. **`SyntaxHighlightedCompletion.swift`** - Rewrite `highlight()` to use full-content highlighting
2. **`CodeCompletionViewModel.swift`** - Update `createDebugCompletion()` to include `oldContent`

## Testing

After implementation:
1. Run the app and trigger the debug completion
2. Verify syntax highlighting colors match Xcode theme
3. Verify multi-line completions are properly highlighted
4. Check performance with larger files
