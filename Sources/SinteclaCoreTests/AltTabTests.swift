import CoreGraphics
import Testing
@testable import SinteclaCore

@Suite struct AltTabTests {
  @Test func commandTabOpensAndShiftGoesBackwards() {
    #expect(AltTabShortcut.key(keyCode: 48, modifiers: [.command], isOpen: false) == .open(backward: false))
    #expect(AltTabShortcut.key(keyCode: 48, modifiers: [.command, .shift], isOpen: false) == .open(backward: true))
    #expect(AltTabShortcut.key(keyCode: 48, modifiers: [.option], isOpen: false) == nil)
    #expect(AltTabShortcut.key(keyCode: 48, modifiers: [.command, .option], isOpen: false) == nil)
    #expect(AltTabShortcut.key(keyCode: 48, modifiers: [.command, .control], isOpen: false) == nil)
    #expect(AltTabShortcut.key(keyCode: 49, modifiers: [.command], isOpen: false) == nil)  // ⌘Espacio no
  }

  @Test func whileOpenTabArrowsAndEscape() {
    #expect(AltTabShortcut.key(keyCode: 48, modifiers: [.command], isOpen: true) == .next)
    #expect(AltTabShortcut.key(keyCode: 48, modifiers: [.command, .shift], isOpen: true) == .previous)
    #expect(AltTabShortcut.key(keyCode: 124, modifiers: [.command], isOpen: true) == .next)  // →
    #expect(AltTabShortcut.key(keyCode: 123, modifiers: [.command], isOpen: true) == .previous)  // ←
    #expect(AltTabShortcut.key(keyCode: 53, modifiers: [.command], isOpen: true) == .cancel)  // Esc
    #expect(AltTabShortcut.key(keyCode: 12, modifiers: [.command], isOpen: true) == nil)  // ⌘Q sigue siendo de la app
  }

  private func window(_ id: Int, pid: Int32 = 10, app: String = "Safari", title: String = "Ventana", minimized: Bool = false,
                      layer: Int = 0, size: CGSize = CGSize(width: 800, height: 600)) -> SwitcherWindow {
    SwitcherWindow(id: id, pid: pid, appName: app, title: title, isMinimized: minimized, layer: layer, size: size)
  }

  @Test func keepsMacOSOrderAndPutsMinimizedLast() {
    let visible = [window(1), window(2, pid: 11, app: "Notas"), window(3)]
    let minimized = [window(-1, pid: 11, app: "Notas", minimized: true)]
    let arranged = WindowSwitcherOrder.arrange(visible: visible, minimized: minimized, ownPID: 99, agentPIDs: [])
    #expect(arranged.map(\.id) == [1, 2, 3, -1])
  }

  @Test func leavesOutSinteclaMenusTinyWindowsAndAgents() {
    let visible = [
      window(1),
      window(2, pid: 99, app: "Sintecla"),  // la propia app
      window(3, layer: 25),  // barra de menú, Dock, paneles
      window(4, size: CGSize(width: 40, height: 300)),  // menos de 50 puntos
      window(5, pid: 12, app: "Ayudante"),  // app de fondo
    ]
    let arranged = WindowSwitcherOrder.arrange(visible: visible, minimized: [window(6, pid: 99, minimized: true)],
                                               ownPID: 99, agentPIDs: [12])
    #expect(arranged.map(\.id) == [1])
  }

  @Test func untitledWindowsShowTheAppName() {
    #expect(window(1, app: "Finder", title: "  ").label == "Finder")
    #expect(window(1, app: "Safari", title: "Inicio").label == "Inicio")
  }

  @Test func startsOnTheSecondOrTheLastBackwards() {
    #expect(SwitcherState(count: 4, backward: false).selected == 1)
    #expect(SwitcherState(count: 4, backward: true).selected == 3)
    #expect(SwitcherState(count: 1, backward: false).selected == 0)
    #expect(SwitcherState(count: 0, backward: false).selected == nil)
  }

  @Test func movesAroundAndTheMouseMarks() {
    var state = SwitcherState(count: 3, backward: false)
    state.next()
    #expect(state.selected == 2)
    state.next()
    #expect(state.selected == 0)  // da la vuelta
    state.previous()
    #expect(state.selected == 2)
    state.mark(1)
    #expect(state.selected == 1)
    state.mark(7)  // fuera de la lista: no cambia
    #expect(state.selected == 1)
    var empty = SwitcherState(count: 0, backward: false)
    empty.next()
    #expect(empty.selected == nil)
  }
}
