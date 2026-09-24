import Testing
@testable import SinteclaCore

@Suite struct HotkeyStateMachineTests {
  @Test func tapStartsHandsFreeDictation() {
    var m = HotkeyStateMachine()
    #expect(m.handle(.baseDown(at: 0)) == [.arm])
    #expect(m.handle(.baseUp(at: 0.1)) == [.startRecording(.dictation, .handsFree)])
  }

  @Test func secondTapFinishesHandsFree() {
    var m = HotkeyStateMachine()
    _ = m.handle(.baseDown(at: 0))
    _ = m.handle(.baseUp(at: 0.1))
    #expect(m.handle(.baseDown(at: 2.0)) == [])
    #expect(m.handle(.baseUp(at: 2.1)) == [.finishRecording])
    #expect(m.state == .busy)
    m.processingFinished()
    #expect(m.state == .idle)
  }

  @Test func holdRecordsUntilRelease() {
    var m = HotkeyStateMachine()
    _ = m.handle(.baseDown(at: 0))
    #expect(m.handle(.tick(at: 0.1)) == [])
    #expect(m.handle(.tick(at: 0.31)) == [.startRecording(.dictation, .hold)])
    #expect(m.handle(.baseUp(at: 3)) == [.finishRecording])
  }

  @Test func releaseAfterThresholdWithoutTickStartsAndFinishes() {
    var m = HotkeyStateMachine()
    _ = m.handle(.baseDown(at: 0))
    #expect(m.handle(.baseUp(at: 0.5)) == [.startRecording(.dictation, .hold), .finishRecording])
    #expect(m.state == .busy)
  }

  @Test func otherKeyWhileArmedCancelsAndPassesThrough() {
    var m = HotkeyStateMachine()
    _ = m.handle(.baseDown(at: 0))
    #expect(m.handle(.otherKey(at: 0.05)) == [.cancel])
    #expect(m.state == .idle)
    #expect(m.handle(.baseUp(at: 0.2)) == [])
  }

  @Test func otherKeyDuringHoldCancels() {
    var m = HotkeyStateMachine()
    _ = m.handle(.baseDown(at: 0))
    _ = m.handle(.tick(at: 0.31))
    #expect(m.handle(.otherKey(at: 0.5)) == [.cancel])
    #expect(m.state == .idle)
  }

  @Test func escapeCancelsAndIsSwallowed() {
    var m = HotkeyStateMachine()
    _ = m.handle(.baseDown(at: 0))
    _ = m.handle(.baseUp(at: 0.1))
    #expect(m.handle(.escape(at: 1)) == [.cancel, .swallowKey])
    #expect(m.state == .idle)
  }

  @Test func shiftSelectsTranslation() {
    var m = HotkeyStateMachine()
    _ = m.handle(.modifiers([.shift], at: 0))
    _ = m.handle(.baseDown(at: 0))
    #expect(m.handle(.baseUp(at: 0.1)) == [.startRecording(.translation, .handsFree)])
  }

  @Test func spaceSelectsAskAndIsSwallowed() {
    var m = HotkeyStateMachine()
    _ = m.handle(.baseDown(at: 0))
    #expect(m.handle(.space(at: 0.05)) == [.swallowKey])
    #expect(m.handle(.baseUp(at: 0.2)) == [.startRecording(.ask, .handsFree)])
  }

  @Test func controlHoldSelectsNotes() {
    var m = HotkeyStateMachine()
    _ = m.handle(.modifiers([.control], at: 0))
    _ = m.handle(.baseDown(at: 0))
    #expect(m.handle(.tick(at: 0.35)) == [.startRecording(.notes, .hold)])
  }

  @Test func optionTogglesMeetingOnRelease() {
    var m = HotkeyStateMachine()
    _ = m.handle(.modifiers([.option], at: 0))
    _ = m.handle(.baseDown(at: 0))
    #expect(m.handle(.tick(at: 0.4)) == [])
    #expect(m.handle(.baseUp(at: 0.5)) == [.cancel, .toggleMeeting])
    #expect(m.state == .idle)
  }

  @Test func rightOptionBaseUsesCommandForMeetingAndIgnoresOption() {
    var m = HotkeyStateMachine(baseKey: .rightOption)
    _ = m.handle(.modifiers([.command], at: 0))
    _ = m.handle(.baseDown(at: 0))
    #expect(m.handle(.baseUp(at: 0.1)) == [.cancel, .toggleMeeting])
    #expect(HotkeyLayout.defaults.mode(modifiers: [.option], sawSpace: false, baseKey: .rightOption) == .dictation)
  }

  /// Con las dos bases, la reunión es 🌐 + ⌥ o ⌥ derecha + ⌘ (la máquina no sabe cuál se pulsó).
  @Test func bothBasesTakeOptionOrCommandForMeeting() {
    #expect(HotkeyLayout.defaults.mode(modifiers: [.option], sawSpace: false, baseKey: .both) == .meeting)
    #expect(HotkeyLayout.defaults.mode(modifiers: [.command], sawSpace: false, baseKey: .both) == .meeting)
    #expect(HotkeyLayout.defaults.mode(modifiers: [.shift], sawSpace: false, baseKey: .both) == .translation)
    #expect(HotkeyLayout.defaults.mode(modifiers: [], sawSpace: false, baseKey: .both) == .dictation)
  }

  @Test func theMachineUsesTheLayout() {
    var layout = HotkeyLayout.defaults
    layout.assign(.option, to: .notes)  // la reunión pasa a ⌃
    var m = HotkeyStateMachine(layout: layout)
    _ = m.handle(.modifiers([.control], at: 0))
    _ = m.handle(.baseDown(at: 0))
    #expect(m.handle(.baseUp(at: 0.1)) == [.cancel, .toggleMeeting])
  }

  /// Si Espacio no es de ningún modo, base + Espacio es otra tecla: cancela y el Espacio llega a la app.
  @Test func aFreeSpaceCancelsAndPassesThrough() {
    var layout = HotkeyLayout.defaults
    layout.assign(.command, to: .ask)
    var armed = HotkeyStateMachine(layout: layout)
    _ = armed.handle(.baseDown(at: 0))
    #expect(armed.handle(.space(at: 0.1)) == [.cancel])
    #expect(armed.state == .idle)
    var holding = HotkeyStateMachine(layout: layout)
    _ = holding.handle(.baseDown(at: 0))
    _ = holding.handle(.tick(at: 0.4))
    #expect(holding.handle(.space(at: 0.5)) == [.cancel])
    #expect(holding.state == .idle)
  }

  @Test func busyGivesFeedback() {
    var m = HotkeyStateMachine()
    _ = m.handle(.baseDown(at: 0))
    _ = m.handle(.baseUp(at: 0.5))
    #expect(m.handle(.baseDown(at: 1)) == [.busyFeedback])
  }

  @Test func systemShortcutDuringHandsFreeDoesNotFinish() {
    var m = HotkeyStateMachine()
    _ = m.handle(.baseDown(at: 0))
    _ = m.handle(.baseUp(at: 0.1))
    _ = m.handle(.baseDown(at: 2))
    _ = m.handle(.otherKey(at: 2.05))
    #expect(m.handle(.baseUp(at: 2.1)) == [])
    #expect(m.state == .recording(mode: .dictation, style: .handsFree, baseDownAt: nil, otherKeyWhileBaseDown: false))
  }
}
