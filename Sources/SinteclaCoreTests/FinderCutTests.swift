import Testing
@testable import SinteclaCore

@Suite struct FinderCutTests {
  let finder = FinderCut.finderBundleID

  /// ⌘X o ⌘V en Finder, sin escribir, con el interruptor encendido.
  private func press(_ key: FinderCut.Key, _ cut: inout FinderCut, changeCount: Int, app: String? = FinderCut.finderBundleID) -> FinderCut.Decision {
    cut.keyDown(key, enabled: true, app: app, changeCount: changeCount, isEditingText: { false })
  }

  @Test func onlyCommandXAndCommandVCount() {
    #expect(FinderCut.key(keyCode: 7, modifiers: [.command]) == .cut)
    #expect(FinderCut.key(keyCode: 9, modifiers: [.command]) == .paste)
    #expect(FinderCut.key(keyCode: 7, modifiers: [.command, .shift]) == nil)
    #expect(FinderCut.key(keyCode: 9, modifiers: [.command, .option]) == nil)
    #expect(FinderCut.key(keyCode: 7, modifiers: []) == nil)
    #expect(FinderCut.key(keyCode: 8, modifiers: [.command]) == nil)
  }

  @Test func passesWhenOffOutsideFinderOrWriting() {
    var cut = FinderCut()
    #expect(cut.keyDown(.cut, enabled: false, app: finder, changeCount: 1, isEditingText: { false }) == .pass)
    #expect(cut.keyDown(.cut, enabled: true, app: "com.apple.Notes", changeCount: 1, isEditingText: { false }) == .pass)
    #expect(cut.keyDown(.cut, enabled: true, app: nil, changeCount: 1, isEditingText: { false }) == .pass)
    #expect(cut.keyDown(.cut, enabled: true, app: finder, changeCount: 1, isEditingText: { true }) == .pass)
    #expect(cut.keyDown(.paste, enabled: true, app: finder, changeCount: 1, isEditingText: { true }) == .pass)
  }

  @Test func asksWhetherWritingOnlyInFinderWithTheToolOn() {
    var cut = FinderCut()
    var asked = 0
    _ = cut.keyDown(.cut, enabled: false, app: finder, changeCount: 1, isEditingText: { asked += 1; return false })
    _ = cut.keyDown(.cut, enabled: true, app: "com.apple.Notes", changeCount: 1, isEditingText: { asked += 1; return false })
    #expect(asked == 0)
    _ = cut.keyDown(.cut, enabled: true, app: finder, changeCount: 1, isEditingText: { asked += 1; return false })
    #expect(asked == 1)
  }

  @Test func cutThenPasteMovesOnce() {
    var cut = FinderCut()
    #expect(press(.cut, &cut, changeCount: 4) == .copyAsCut)
    #expect(cut.copied(changeCount: 5, files: 3) == "Cortado: 3 elementos · ⌘V para mover")
    #expect(press(.paste, &cut, changeCount: 5) == .move)
    // El corte se olvida: el siguiente ⌘V pega como siempre.
    #expect(press(.paste, &cut, changeCount: 5) == .pass)
  }

  @Test func nothingIsCutWithoutChangeOrFiles() {
    var cut = FinderCut()
    _ = press(.cut, &cut, changeCount: 4)
    #expect(cut.copied(changeCount: 4, files: 0) == nil)  // no había nada seleccionado
    #expect(press(.paste, &cut, changeCount: 4) == .pass)
    _ = press(.cut, &cut, changeCount: 4)
    #expect(cut.copied(changeCount: 5, files: 0) == nil)  // cambió, pero sin archivos
    #expect(press(.paste, &cut, changeCount: 5) == .pass)
  }

  @Test func copyingSomethingElseForgetsTheCut() {
    var cut = FinderCut()
    _ = press(.cut, &cut, changeCount: 4)
    _ = cut.copied(changeCount: 5, files: 2)
    #expect(press(.paste, &cut, changeCount: 6) == .pass)
    #expect(press(.paste, &cut, changeCount: 5) == .pass)
  }

  @Test func cutWithNothingSelectedKeepsThePreviousCut() {
    var cut = FinderCut()
    _ = press(.cut, &cut, changeCount: 4)
    _ = cut.copied(changeCount: 5, files: 2)
    _ = press(.cut, &cut, changeCount: 5)
    #expect(cut.copied(changeCount: 5, files: 2) == nil)
    #expect(press(.paste, &cut, changeCount: 5) == .move)
  }

  @Test func pasteOutsideFinderKeepsTheCut() {
    var cut = FinderCut()
    _ = press(.cut, &cut, changeCount: 4)
    _ = cut.copied(changeCount: 5, files: 2)
    #expect(press(.paste, &cut, changeCount: 5, app: "com.apple.Notes") == .pass)
    #expect(press(.paste, &cut, changeCount: 5) == .move)
  }

  @Test func copiedWithoutCutDoesNothing() {
    var cut = FinderCut()
    #expect(cut.copied(changeCount: 5, files: 2) == nil)
    #expect(press(.paste, &cut, changeCount: 5) == .pass)
  }

  @Test func noticeInSingularAndPlural() {
    #expect(FinderCut.notice(files: 1) == "Cortado: 1 elemento · ⌘V para mover")
    #expect(FinderCut.notice(files: 3) == "Cortado: 3 elementos · ⌘V para mover")
  }
}
