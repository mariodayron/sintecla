import Foundation
import Testing
@testable import SinteclaCore

@Suite struct HotkeyLayoutTests {
  let layout = HotkeyLayout.defaults

  @Test func theDefaultsAreTheShortcutsOfAlways() {
    #expect(layout.companion(for: .translation) == .shift)
    #expect(layout.companion(for: .ask) == .space)
    #expect(layout.companion(for: .notes) == .control)
    #expect(layout.companion(for: .meeting) == .option)
    #expect(layout.companion(for: .dictation) == nil)
  }

  /// Con los valores por defecto, el modo sale igual que antes de la F4c con las tres bases.
  @Test(arguments: BaseKey.allCases)
  func theDefaultsDecideLikeBefore(_ base: BaseKey) {
    #expect(layout.mode(modifiers: [], sawSpace: false, baseKey: base) == .dictation)
    #expect(layout.mode(modifiers: [.shift], sawSpace: false, baseKey: base) == .translation)
    #expect(layout.mode(modifiers: [], sawSpace: true, baseKey: base) == .ask)
    #expect(layout.mode(modifiers: [.control], sawSpace: false, baseKey: base) == .notes)
    #expect(layout.mode(modifiers: [.option], sawSpace: false, baseKey: base) == (base == .rightOption ? .dictation : .meeting))
    #expect(layout.mode(modifiers: [.command], sawSpace: false, baseKey: base) == (base == .fn ? .dictation : .meeting))
  }

  @Test func spaceFirstThenShiftControlOptionCommand() {
    #expect(layout.mode(modifiers: [.shift, .control], sawSpace: true, baseKey: .fn) == .ask)
    #expect(layout.mode(modifiers: [.shift, .control, .option], sawSpace: false, baseKey: .fn) == .translation)
    #expect(layout.mode(modifiers: [.control, .option], sawSpace: false, baseKey: .fn) == .notes)
  }

  @Test func aTakenKeyIsSwapped() {
    var layout = layout
    layout.assign(.option, to: .notes)
    #expect(layout.companion(for: .notes) == .option)
    #expect(layout.companion(for: .meeting) == .control)
    layout.assign(.space, to: .translation)
    #expect(layout.companion(for: .translation) == .space)
    #expect(layout.companion(for: .ask) == .shift)
    // Una tecla libre no quita nada a nadie.
    layout.assign(.command, to: .notes)
    #expect(layout.companion(for: .notes) == .command)
    #expect(layout.mode(for: .option) == nil)
  }

  @Test func commandStandsInForOptionWithRightOption() {
    var layout = layout
    layout.assign(.option, to: .notes)
    #expect(layout.mode(modifiers: [.command], sawSpace: false, baseKey: .rightOption) == .notes)
    #expect(layout.mode(modifiers: [.command], sawSpace: false, baseKey: .both) == .notes)
    #expect(layout.mode(modifiers: [.command], sawSpace: false, baseKey: .fn) == .dictation)
    // Si ⌘ es de otro modo, ⌘ es de ese modo.
    layout.assign(.command, to: .ask)
    #expect(layout.mode(modifiers: [.command], sawSpace: false, baseKey: .both) == .ask)
    #expect(layout.mode(modifiers: [.option], sawSpace: false, baseKey: .both) == .notes)
  }

  @Test func aFreeKeyDoesNothing() {
    var layout = layout
    layout.assign(.command, to: .ask)
    #expect(!layout.usesSpace)
    #expect(layout.mode(modifiers: [], sawSpace: true, baseKey: .fn) == .dictation)
    #expect(HotkeyLayout.defaults.usesSpace)
  }

  @Test func shortcutsWithEachBaseKey() {
    #expect(layout.shortcut(for: .dictation, baseKey: .fn) == "🌐")
    #expect(layout.shortcut(for: .dictation, baseKey: .rightOption) == "⌥ der")
    #expect(layout.shortcut(for: .dictation, baseKey: .both) == "🌐 o ⌥ der")
    #expect(layout.shortcut(for: .translation, baseKey: .fn) == "🌐 + ⇧")
    #expect(layout.shortcut(for: .ask, baseKey: .rightOption) == "⌥ der + Espacio")
    #expect(layout.shortcut(for: .notes, baseKey: .both) == "🌐 o ⌥ der + ⌃")
    #expect(layout.shortcut(for: .meeting, baseKey: .fn) == "🌐 + ⌥")
    #expect(layout.shortcut(for: .meeting, baseKey: .rightOption) == "⌥ der + ⌘")
    #expect(layout.shortcut(for: .meeting, baseKey: .both) == "🌐 + ⌥ o ⌥ der + ⌘")
  }

  @Test func theOptionModeLosesItsShortcutWhenCommandIsTaken() {
    var layout = layout
    layout.assign(.command, to: .notes)
    #expect(layout.shortcut(for: .meeting, baseKey: .rightOption) == nil)
    #expect(layout.shortcut(for: .meeting, baseKey: .both) == "🌐 + ⌥")
    #expect(layout.warning(for: .meeting, baseKey: .rightOption)
      == "Con ⌥ derecha, Reunión no tiene atajo: ⌥ es la propia tecla base. Ponle otra tecla o deja ⌘ libre.")
    #expect(layout.warning(for: .meeting, baseKey: .both)
      == "Reunión solo funciona con 🌐: con ⌥ derecha, ⌥ es la propia tecla base. Ponle otra tecla o deja ⌘ libre.")
    #expect(layout.warning(for: .meeting, baseKey: .fn) == nil)
    #expect(layout.warning(for: .notes, baseKey: .rightOption) == nil)
    #expect(HotkeyLayout.defaults.warning(for: .meeting, baseKey: .rightOption) == nil)
  }

  @Test func savesAndReadsBack() throws {
    var layout = layout
    layout.assign(.option, to: .notes)
    #expect(HotkeyLayout.decoded(try JSONEncoder().encode(layout)) == layout)
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    #expect(String(decoding: try encoder.encode(HotkeyLayout.defaults), as: UTF8.self)
      == #"{"ask":"space","meeting":"option","notes":"control","translation":"shift"}"#)
  }

  @Test(arguments: [
    nil,
    "no es json",
    #"{"translation":"shift","ask":"space","notes":"control"}"#,
    #"{"translation":"shift","ask":"shift","notes":"control","meeting":"option"}"#,
    #"{"translation":"shift","ask":"space","notes":"control","meeting":"tecla"}"#,
    #"{"translation":"shift","ask":"space","notes":"control","meeting":"option","dictation":"command"}"#,
  ] as [String?])
  func badDataGivesTheDefaults(_ json: String?) {
    #expect(HotkeyLayout.decoded(json.map { Data($0.utf8) }) == .defaults)
  }
}
