import Testing
@testable import SinteclaCore

/// Teclas físicas: 63 = 🌐/Fn, 61 = ⌥ derecha.
@Suite struct BaseKeyTrackerTests {
  @Test func fnBaseIgnoresRightOption() {
    var t = BaseKeyTracker(baseKey: .fn)
    #expect(t.update(keyCode: 61, fnDown: false, rightOptionDown: true) == nil)
    #expect(t.update(keyCode: 63, fnDown: true, rightOptionDown: true) == true)
    #expect(t.update(keyCode: 63, fnDown: false, rightOptionDown: true) == false)
  }

  /// Teclados como algunos Logitech no mandan su Fn al Mac: con `.both` sirve también la ⌥ derecha.
  @Test func bothAcceptsEitherKey() {
    var t = BaseKeyTracker(baseKey: .both)
    #expect(t.update(keyCode: 63, fnDown: true, rightOptionDown: false) == true)
    #expect(t.active == .fn)
    #expect(t.update(keyCode: 63, fnDown: false, rightOptionDown: false) == false)
    #expect(t.update(keyCode: 61, fnDown: false, rightOptionDown: true) == true)
    #expect(t.active == .rightOption)
    #expect(t.update(keyCode: 61, fnDown: false, rightOptionDown: false) == false)
    #expect(t.active == nil)
  }

  @Test func withBothTheFirstKeyWinsUntilReleased() {
    var t = BaseKeyTracker(baseKey: .both)
    _ = t.update(keyCode: 63, fnDown: true, rightOptionDown: false)
    // Con 🌐 abajo, la ⌥ derecha no es otra base: es el modificador ⌥.
    #expect(t.update(keyCode: 61, fnDown: true, rightOptionDown: true) == nil)
    #expect(t.optionIsModifier)
    #expect(t.update(keyCode: 61, fnDown: true, rightOptionDown: false) == nil)
    #expect(t.update(keyCode: 63, fnDown: false, rightOptionDown: false) == false)
  }

  @Test func optionIsNotAModifierWhileRightOptionIsTheBase() {
    #expect(!BaseKeyTracker(baseKey: .rightOption).optionIsModifier)
    #expect(BaseKeyTracker(baseKey: .fn).optionIsModifier)
    var t = BaseKeyTracker(baseKey: .both)
    #expect(t.optionIsModifier)
    _ = t.update(keyCode: 61, fnDown: false, rightOptionDown: true)
    #expect(!t.optionIsModifier)
  }
}
