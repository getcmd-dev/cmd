// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import AppFoundation
import AppKit
import SwiftUI

// MARK: - RichTextEditor

/// A text editor that supports including block elements, rich text formatting and inline search.
///
/// `block elements` are elements that are atomic. They are not editable, are deleted / selected at once.
/// They are represented by the `NSAttributedString.Key.textBlock` attribute.
/// The text can use the property `lockedAttributes` to describe attributes that should not be added to new text.
public struct RichTextEditor: NSViewRepresentable {

  /// - Parameters:
  ///   - text: The text in the input. Supports rich formatting.
  ///   - font: The default font to use for new text entered by the user.
  ///   - needsFocus: Whether the input should become first responder when possible.
  ///   - onFocusChanged: Called when by the text view when its focus changes.
  ///   - onSearch: Called when the user types a search query. The owner of the text editor is responsible for updating the text if a search result is selected.
  ///   - onKeyDown: Called when the user presses a key. Return true to prevent the default behavior.
  ///   - placeholder: A placeholder to display when no text is entered.
  public init(
    text: Binding<NSAttributedString>,
    font: NSFont = NSFont.preferredFont(forTextStyle: .title3, options: [:]),
    needsFocus: Binding<Bool> = .constant(false),
    onFocusChanged: @escaping (Bool) -> Void = { _ in },
    onSearch: @escaping ((String, NSRange, CGRect?)?) -> Void = { _ in },
    onKeyDown: ((KeyEquivalent, [KeyModifier]) -> Bool)? = nil,
    placeholder: String = "")
  {
    _text = text
    _needsFocus = needsFocus
    self.font = font
    self.onFocusChanged = onFocusChanged
    self.onSearch = onSearch
    self.onKeyDown = onKeyDown
    self.placeholder = placeholder
  }

  public class Coordinator: NSObject, NSTextViewDelegate {

    init(_ parent: RichTextEditor) {
      self.parent = parent
    }

    public func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      if let string = textView.textStorage {
        // Note: prior to Xcode 26 / Swift 6.2, this triggerred a warning “Modifying state during view update, this will cause undefined behavior.”
        // If the issue persists, simply wrapping in a Task is buggy as we need to prevent and change to the text in `updateNSView` until the
        // update has been propagated (ie the View is re-created in between, it'll have the old text value).
        parent.text = string
      }

      // Force layout update to resize the text view
      if let expandingTextView = textView as? RichTextView {
        expandingTextView.invalidateIntrinsicContentSize()
      }

      (textView.selectedRanges.last as? NSRange).map { handleSearch(textView: textView, selection: $0) }
    }

    public func textViewDidChangeSelection(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      if textView.selectedRange().length > 0 {
        parent.onFocusChanged(true)
      }
      (textView.selectedRanges.last as? NSRange).map { handleSearch(textView: textView, selection: $0) }
    }

    public func textDidBeginEditing(_: Notification) {
      parent.onFocusChanged(true)
    }

    public func textDidEndEditing(_: Notification) {
      parent.onFocusChanged(false)
    }

    public func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString _: String?) -> Bool {
      updateTypingAttributes(textView: textView, editedRange: range)
      return true
    }

    public func textView(
      _ textView: NSTextView,
      willChangeSelectionFromCharacterRange oldSelectedCharRange: NSRange,
      toCharacterRange newSelectedCharRange: NSRange)
      -> NSRange
    {
      if
        let updatedRange = textView.textStorage?.adjustedTextBlockRangeOnSelectionChange(
          oldRange: oldSelectedCharRange,
          newRange: newSelectedCharRange)
      {
        return updatedRange
      }
      return newSelectedCharRange
    }

    private let parent: RichTextEditor

    @MainActor
    private func updateTypingAttributes(textView: NSTextView, editedRange: NSRange) {
      guard let textView = textView as? RichTextView else { return }
      // Should this just be textView.resetTypingAttributes()?
      guard let attrString = textView.textStorage else {
        return
      }
      guard
        editedRange.location > 0,
        editedRange.location <= attrString.length
      else {
        return
      }

      let attributes = attrString.attributes(at: editedRange.location - 1, effectiveRange: nil)
      for attribute in attributes {
        textView.typingAttributes[attribute.key] = attribute.value
      }

      // Drop locked attributes
      if let lockedAttributes = attributes.first(where: { $0.key == .lockedAttributes })?.value as? [NSAttributedString.Key] {
        for attribute in lockedAttributes {
          textView.typingAttributes[attribute] = nil
        }
      }
      textView.typingAttributes.removeValue(forKey: .lockedAttributes)
      textView.typingAttributes.removeValue(forKey: .textBlock)

      // Always set those attributes back to those of the text's view.
      textView.typingAttributes[.foregroundColor] = textView.defaultTextColor
      textView.typingAttributes[.backgroundColor] = textView.defaultBackgroundColor
      textView.typingAttributes[.font] = textView.defaultFont
    }

    @MainActor
    private func handleSearch(textView: NSTextView, selection: NSRange) {
      guard let attrString = textView.textStorage else { return }
      if let searchRange = attrString.searchRange(from: selection) {
        var searchSymbolPosition: CGRect?
        if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
          let rect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: searchRange.location, length: 1),
            in: textContainer)
          let offset = textView.textContainerOrigin
          searchSymbolPosition = NSRect(
            origin: NSPoint(x: rect.origin.x + offset.x, y: rect.origin.y + offset.y),
            size: rect.size)
        }
        // Remove the first character that is the `@` search key.
        let searchQuery = String(attrString.attributedSubstring(from: searchRange).string.dropFirst())
        parent.onSearch((searchQuery, searchRange, searchSymbolPosition))
      } else {
        parent.onSearch(nil)
      }
    }
  }

  public func makeNSView(context: Context) -> NSTextView {
    let textView = RichTextView()
    textView.placeholder = placeholder

    textView.delegate = context.coordinator
    textView.defaultFont = font
    textView.defaultBackgroundColor = .clear
    textView.defaultTextColor = .textColor
    textView.isEditable = true
    textView.isSelectable = true
    textView.isRichText = true
    textView.allowsUndo = true
    textView.onKeyDown = onKeyDown.map { onKeyDown in { k, m in onKeyDown(k, .init(m)) } }

    textView.resetTypingAttributes()

    // Disable scrolling since we want it to expand
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask = [.width]

    // Text wrapping
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.containerSize = NSSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude)

    updateNSView(textView, context: context)
    return textView
  }

  public func updateNSView(_ textView: NSTextView, context _: Context) {
    guard let textView = textView as? RichTextView else { return }

    if textView.string != text.string {
      // Skip text updates while IME composition is in progress to prevent losing marked text
      if !textView.hasMarkedText() {
        let string = NSMutableAttributedString(attributedString: text)
        string.enumerateAttributes(in: NSRange(location: 0, length: string.length), options: []) { attributes, range, _ in
          var newAttributes = [NSAttributedString.Key: Any]()
          // Default values.
          newAttributes[.font] = textView.font
          newAttributes[.foregroundColor] = textView.textColor

          // Don't update values for locked attributes.
          (attributes[.lockedAttributes] as? [NSAttributedString.Key])?.forEach { lockedAttribute in
            newAttributes.removeValue(forKey: lockedAttribute)
          }
          string.setAttributes(attributes.merging(newAttributes, uniquingKeysWith: { _, b in b }), range: range)
        }

        textView.undoManager?.beginUndoGrouping()
        textView.replaceCharacters(in: nil, with: string)
        textView.undoManager?.endUndoGrouping()
        textView.didChangeText()
      }
    }

    if needsFocus {
      textView.onFocus = {
        $needsFocus.wrappedValue = false
      }
    } else {
      textView.onFocus = nil
    }
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  /// The input's content.
  @Binding var text: NSAttributedString
  /// Whether the input should become first responded when possible.
  @Binding var needsFocus: Bool

  /// The placeholder to show when no text is entered.
  let placeholder: String

  private let onFocusChanged: (Bool) -> Void
  private let onSearch: ((String, NSRange, CGRect?)?) -> Void
  private let onKeyDown: ((KeyEquivalent, [KeyModifier]) -> Bool)?

  private let font: NSFont

}

// MARK: - RichTextView

private class RichTextView: NSTextView {

  var placeholder: String?

  var onKeyDown: ((KeyEquivalent, NSEvent.ModifierFlags) -> Bool)?

  var defaultTextColor: NSColor? {
    didSet {
      textColor = defaultTextColor
    }
  }

  var defaultFont: NSFont? {
    didSet {
      font = defaultFont
    }
  }

  var defaultBackgroundColor: NSColor? {
    didSet {
      backgroundColor = defaultBackgroundColor ?? .clear
    }
  }

  override var intrinsicContentSize: NSSize {
    guard
      let textContainer,
      let layoutManager
    else {
      return super.intrinsicContentSize
    }

    layoutManager.ensureLayout(for: textContainer)
    let contentHeight = layoutManager.usedRect(for: textContainer).height
    return NSSize(width: NSView.noIntrinsicMetric, height: max(contentHeight, 20))
  }

  /// Setting on focus will trigger the text view to request focus when possible. It will then use the call back to signal that focus was set.
  @MainActor var onFocus: (() -> Void)? = nil {
    didSet {
      handleFocus()
    }
  }

  override func didChangeText() {
    super.didChangeText()
    invalidateIntrinsicContentSize()
    needsLayout = true
    placeholderLabel?.isHidden = !string.isEmpty
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    handleFocus()

    if !hasSetup {
      setup()
    }
  }

  override func keyDown(with event: NSEvent) {
    // First, let the input method handle the event if there's marked text (composition in progress)
    // This ensures IME events (like ESC to cancel composition) don't trigger custom key handlers
    if hasMarkedText() {
      super.keyDown(with: event)
      return
    }

    guard let onKeyDown, let firstChar = event.charactersIgnoringModifiers?.first else {
      super.keyDown(with: event)
      return
    }
    var key = KeyEquivalent(firstChar)

    if key == KeyEquivalent("\u{19}") {
      // When tab is pressed with shift, the key we get is \u{19} while without the modifier we get \t
      key = .tab
    } else if key == KeyEquivalent("\u{7F}") {
      // Somehow not mapped correctly
      key = .delete
    }

    let handled = onKeyDown(key, event.modifierFlags.intersection(.deviceIndependentFlagsMask))
    if handled {
      return
    }

    super.keyDown(with: event)
  }

  override func paste(_ sender: Any?) {
    // Remove rich text attributes from the pasted text.
    super.pasteAsPlainText(sender)
  }

  override func deleteBackward(_ sender: Any?) {
    guard let attributedText = textStorage else {
      super.deleteBackward(sender)
      return
    }
    defer {
      if attributedText.length == 0 {
        resetTypingAttributes()
      }
    }

    guard attributedText.length > 0 else {
      super.deleteBackward(sender)
      return
    }
    let proposedRange = NSRange(location: max(0, selectedRange.location - 1), length: 0)
    let attributeExists = (attributedText.attribute(.textBlock, at: proposedRange.location, effectiveRange: nil)) != nil

    guard
      attributeExists,
      let textRange = attributedText.adjustedTextBlockRangeOnSelectionChange(oldRange: selectedRange, newRange: proposedRange)
    else {
      super.deleteBackward(sender)
      return
    }

    undoManager?.beginUndoGrouping()
    let deletedRangeLength = selectedRange.location - textRange.location
    let rangeToDelete = NSRange(location: textRange.location, length: deletedRangeLength)
    replaceCharacters(in: rangeToDelete, with: NSAttributedString(""))
    undoManager?.endUndoGrouping()

    selectedRange = NSRange(location: textRange.location, length: 0)
    delegate?.textDidChange?(Notification(name: NSNotification.Name(rawValue: "NSTextDidChangeNotification"), object: self))
  }

  func resetTypingAttributes() {
    typingAttributes = [:]
    // Always set those attributes back to those of the text's view.
    typingAttributes[.foregroundColor] = defaultTextColor
    typingAttributes[.backgroundColor] = defaultBackgroundColor
    typingAttributes[.font] = defaultFont

    isAutomaticTextReplacementEnabled = false
    isAutomaticQuoteSubstitutionEnabled = false
    isAutomaticDashSubstitutionEnabled = false
    isAutomaticSpellingCorrectionEnabled = false
    isContinuousSpellCheckingEnabled = false
    isAutomaticDashSubstitutionEnabled = false
    isGrammarCheckingEnabled = false
  }

  private var placeholderLabel: InputPlaceholder?

  private var hasSetup = false

  private func setup() {
    guard !hasSetup, let placeholder else { return }
    hasSetup = true

    let placeholderLabel = InputPlaceholder()
    placeholderLabel.frame = CGRect(origin: .zero, size: CGSize(width: 100, height: 44))
    placeholderLabel.font = font
    placeholderLabel.stringValue = placeholder
    placeholderLabel.backgroundColor = .clear
    placeholderLabel.isBezeled = false
    placeholderLabel.isEditable = false
    placeholderLabel.sizeToFit()

    self.placeholderLabel = placeholderLabel
    addSubview(placeholderLabel)
    placeholderLabel.textColor = .tertiaryLabelColor
    placeholderLabel.isHidden = !string.isEmpty
  }

  @MainActor
  private func handleFocus() {
    if let onFocus {
      if let window {
        Task { @MainActor in
          window.makeFirstResponder(self)
          onFocus()
        }
        self.onFocus = nil
      }
    }
  }

}

// MARK: - InputPlaceholder

private class InputPlaceholder: NSTextField {
  override func hitTest(_: NSPoint) -> NSView? {
    nil
  }
}

extension NSAttributedString.Key {
  public static let textBlock = NSAttributedString.Key("_textBlock")
  public static let lockedAttributes = NSAttributedString.Key("_lockedAttributes")
}

extension RichTextView {
  func replaceCharacters(in range: NSRange?, with newString: NSAttributedString) {
    guard let textStorage else { return }
    let range = range ?? NSRange(location: 0, length: textStorage.length)
    insertText(newString.string, replacementRange: range)

    textStorage.beginEditing()
    newString.enumerateAttributes(in: NSRange(location: 0, length: newString.length), options: []) { attributes, r, _ in
      textStorage.setAttributes(attributes, range: NSRange(location: range.location + r.location, length: r.length))
    }
    textStorage.endEditing()
  }
}
