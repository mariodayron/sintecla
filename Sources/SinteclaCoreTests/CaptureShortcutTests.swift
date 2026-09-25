import Testing
@testable import SinteclaCore

@Suite struct CaptureShortcutTests {
  @Test func shiftCommandOneToFour() {
    #expect(CaptureShortcut.action(keyCode: 18, modifiers: [.shift, .command]) == .textCard)
    #expect(CaptureShortcut.action(keyCode: 19, modifiers: [.shift, .command]) == .text)
    #expect(CaptureShortcut.action(keyCode: 20, modifiers: [.shift, .command]) == .screen)
    #expect(CaptureShortcut.action(keyCode: 21, modifiers: [.shift, .command]) == .area)
  }

  @Test func otherKeysOrModifiersDoNothing() {
    #expect(CaptureShortcut.action(keyCode: 20, modifiers: [.command]) == nil)
    #expect(CaptureShortcut.action(keyCode: 20, modifiers: [.shift, .command, .control]) == nil)
    #expect(CaptureShortcut.action(keyCode: 20, modifiers: [.shift, .command, .option]) == nil)
    #expect(CaptureShortcut.action(keyCode: 23, modifiers: [.shift, .command]) == nil)  // ⇧⌘5 es de macOS
    #expect(CaptureShortcut.action(keyCode: 7, modifiers: [.shift, .command]) == nil)
  }

  @Test func labelsForMenuAndPage() {
    #expect(CaptureAction.screen.shortcut == "⇧⌘3")
    #expect(CaptureAction.textCard.shortcut == "⇧⌘1")
    #expect(CaptureAction.allCases.map(\.title) == ["Capturar pantalla", "Capturar zona o ventana", "Copiar texto",
                                                    "Texto con traducir y preguntar"])
    #expect(CaptureAction.area.key == "4")
  }
}
