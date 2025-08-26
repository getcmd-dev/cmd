// Copyright cmd app, Inc. Licensed under the Apache License, Version 2.0.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import KeyboardShortcuts
import SwiftUI
import Testing
@testable import App

struct XcodeKeyboardShortcutsTests {
  @Test("Key conversions")
  func test_keyConversions() {
    #expect(KeyboardShortcuts.Key(character: "a") == .a)
    #expect(KeyboardShortcuts.Key(character: "b") == .b)
    #expect(KeyboardShortcuts.Key(character: "c") == .c)
    #expect(KeyboardShortcuts.Key(character: "d") == .d)
    #expect(KeyboardShortcuts.Key(character: "e") == .e)
    #expect(KeyboardShortcuts.Key(character: "f") == .f)
    #expect(KeyboardShortcuts.Key(character: "g") == .g)
    #expect(KeyboardShortcuts.Key(character: "h") == .h)
    #expect(KeyboardShortcuts.Key(character: "i") == .i)
    #expect(KeyboardShortcuts.Key(character: "j") == .j)
    #expect(KeyboardShortcuts.Key(character: "k") == .k)
    #expect(KeyboardShortcuts.Key(character: "l") == .l)
    #expect(KeyboardShortcuts.Key(character: "m") == .m)
    #expect(KeyboardShortcuts.Key(character: "n") == .n)
    #expect(KeyboardShortcuts.Key(character: "o") == .o)
    #expect(KeyboardShortcuts.Key(character: "p") == .p)
    #expect(KeyboardShortcuts.Key(character: "q") == .q)
    #expect(KeyboardShortcuts.Key(character: "r") == .r)
    #expect(KeyboardShortcuts.Key(character: "s") == .s)
    #expect(KeyboardShortcuts.Key(character: "t") == .t)
    #expect(KeyboardShortcuts.Key(character: "u") == .u)
    #expect(KeyboardShortcuts.Key(character: "v") == .v)
    #expect(KeyboardShortcuts.Key(character: "w") == .w)
    #expect(KeyboardShortcuts.Key(character: "x") == .x)
    #expect(KeyboardShortcuts.Key(character: "y") == .y)
    #expect(KeyboardShortcuts.Key(character: "z") == .z)
    #expect(KeyboardShortcuts.Key(character: "0") == .zero)
    #expect(KeyboardShortcuts.Key(character: "1") == .one)
    #expect(KeyboardShortcuts.Key(character: "2") == .two)
    #expect(KeyboardShortcuts.Key(character: "3") == .three)
    #expect(KeyboardShortcuts.Key(character: "4") == .four)
    #expect(KeyboardShortcuts.Key(character: "5") == .five)
    #expect(KeyboardShortcuts.Key(character: "6") == .six)
    #expect(KeyboardShortcuts.Key(character: "7") == .seven)
    #expect(KeyboardShortcuts.Key(character: "8") == .eight)
    #expect(KeyboardShortcuts.Key(character: "9") == .nine)

    #expect(KeyboardShortcuts.Key(character: KeyEquivalent.upArrow.character) == .upArrow)
    #expect(KeyboardShortcuts.Key(character: KeyEquivalent.downArrow.character) == .downArrow)
    #expect(KeyboardShortcuts.Key(character: KeyEquivalent.leftArrow.character) == .leftArrow)
    #expect(KeyboardShortcuts.Key(character: KeyEquivalent.rightArrow.character) == .rightArrow)
    #expect(KeyboardShortcuts.Key(character: KeyEquivalent.escape.character) == .escape)
    #expect(KeyboardShortcuts.Key(character: KeyEquivalent.delete.character) == .delete)
    #expect(KeyboardShortcuts.Key(character: KeyEquivalent.deleteForward.character) == .deleteForward)
    #expect(KeyboardShortcuts.Key(character: KeyEquivalent.home.character) == .home)
    #expect(KeyboardShortcuts.Key(character: KeyEquivalent.end.character) == .end)
    #expect(KeyboardShortcuts.Key(character: KeyEquivalent.pageUp.character) == .pageUp)
    #expect(KeyboardShortcuts.Key(character: KeyEquivalent.pageDown.character) == .pageDown)
    #expect(KeyboardShortcuts.Key(character: KeyEquivalent.tab.character) == .tab)
    #expect(KeyboardShortcuts.Key(character: KeyEquivalent.space.character) == .space)
    #expect(KeyboardShortcuts.Key(character: KeyEquivalent.`return`.character) == .`return`)
  }
}
