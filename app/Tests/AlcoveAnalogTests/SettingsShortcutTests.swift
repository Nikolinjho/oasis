import AppKit
import Testing

@testable import AlcoveAnalog

@MainActor
struct SettingsShortcutTests {
  @Test("⌘W — закрытие: обычная W с зажатым Command")
  func commandW() {
    #expect(SettingsShortcut.isClose(Self.keyDown(characters: "w", flags: .command)))
  }

  @Test("W без Command — не закрытие")
  func plainW() {
    #expect(!SettingsShortcut.isClose(Self.keyDown(characters: "w", flags: [])))
  }

  @Test("⇧⌘W — лишний модификатор, не закрытие")
  func shiftCommandW() {
    #expect(!SettingsShortcut.isClose(Self.keyDown(characters: "W", flags: [.command, .shift])))
  }

  @Test("⌘Q — другая буква, не закрытие")
  func commandQ() {
    #expect(!SettingsShortcut.isClose(Self.keyDown(characters: "q", flags: .command)))
  }

  private static func keyDown(characters: String, flags: NSEvent.ModifierFlags) -> NSEvent {
    NSEvent.keyEvent(
      with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
      context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false,
      keyCode: 13)!
  }
}
