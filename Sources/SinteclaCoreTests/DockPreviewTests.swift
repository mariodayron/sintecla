import CoreGraphics
import Foundation
import Testing
@testable import SinteclaCore

@Suite struct DockPreviewTests {
  // MARK: Iconos del Dock

  @Test func onlyApplicationItemsWithAnAppAreApps() {
    let safari = URL(fileURLWithPath: "/Applications/Safari.app")
    #expect(DockItem(subrole: "AXApplicationDockItem", url: safari)?.appURL == safari)
    #expect(DockItem(subrole: "AXFolderDockItem", url: URL(fileURLWithPath: "/Users/x/Downloads")) == nil)
    #expect(DockItem(subrole: "AXTrashDockItem", url: nil) == nil)
    #expect(DockItem(subrole: "AXSeparatorDockItem", url: nil) == nil)
    #expect(DockItem(subrole: "AXApplicationDockItem", url: nil) == nil)
    #expect(DockItem(subrole: "AXApplicationDockItem", url: URL(string: "https://example.com")) == nil)
  }

  // MARK: Coordenadas y lado del Dock

  @Test func accessibilityRectsAreFlippedToScreenCoordinates() {
    // Accesibilidad mide desde arriba a la izquierda de la pantalla principal; AppKit, desde abajo.
    let ax = CGRect(x: 1053, y: 1352, width: 67, height: 83)
    #expect(DockPreviewPlacement.screenRect(fromAccessibility: ax, primaryHeight: 1440)
              == CGRect(x: 1053, y: 5, width: 67, height: 83))
  }

  private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

  @Test func dockSideIsTheNearestScreenEdge() {
    #expect(DockEdge(icon: CGRect(x: 700, y: 4, width: 60, height: 60), screen: screen) == .bottom)
    #expect(DockEdge(icon: CGRect(x: 4, y: 400, width: 60, height: 60), screen: screen) == .left)
    #expect(DockEdge(icon: CGRect(x: 1376, y: 400, width: 60, height: 60), screen: screen) == .right)
    // Con la lupa el icono crece, pero sigue pegado a su borde.
    #expect(DockEdge(icon: CGRect(x: 700, y: 4, width: 120, height: 120), screen: screen) == .bottom)
  }

  // MARK: Dónde va la vista

  private let panel = CGSize(width: 400, height: 150)

  @Test func withTheDockAtTheBottomTheViewGoesAboveTheIconCentered() {
    // 36 puntos por encima del icono: el nombre que pone el Dock queda libre.
    let icon = CGRect(x: 700, y: 4, width: 60, height: 60)
    let frame = DockPreviewPlacement.frame(panel: panel, icon: icon, edge: .bottom, screen: screen)
    #expect(frame == CGRect(x: 530, y: 100, width: 400, height: 150))
  }

  @Test func withTheDockAtASideTheViewGoesInwards() {
    let left = CGRect(x: 4, y: 400, width: 60, height: 60)
    #expect(DockPreviewPlacement.frame(panel: panel, icon: left, edge: .left, screen: screen)
              == CGRect(x: 100, y: 355, width: 400, height: 150))
    let right = CGRect(x: 1376, y: 400, width: 60, height: 60)
    #expect(DockPreviewPlacement.frame(panel: panel, icon: right, edge: .right, screen: screen)
              == CGRect(x: 940, y: 355, width: 400, height: 150))
  }

  @Test func nearAScreenEdgeTheViewSlidesUntilItFits() {
    let first = CGRect(x: 10, y: 4, width: 60, height: 60)
    #expect(DockPreviewPlacement.frame(panel: panel, icon: first, edge: .bottom, screen: screen).minX == 8)
    let last = CGRect(x: 1370, y: 4, width: 60, height: 60)
    #expect(DockPreviewPlacement.frame(panel: panel, icon: last, edge: .bottom, screen: screen).maxX == 1432)
    let top = CGRect(x: 4, y: 830, width: 60, height: 60)
    #expect(DockPreviewPlacement.frame(panel: panel, icon: top, edge: .left, screen: screen).maxY == 892)
  }

  // MARK: Tiempos

  private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

  @Test func appearsOnlyAfterTheDelay() {
    var timer = DockHoverTimer<String>()
    #expect(timer.hover("Safari", at: t0) == .none)
    #expect(timer.tick(inside: true, at: t0 + 0.2) == .none)
    #expect(timer.tick(inside: true, at: t0 + 0.3) == .show("Safari"))
    #expect(timer.shown == "Safari")
    #expect(timer.tick(inside: true, at: t0 + 0.5) == .none)
  }

  @Test func leavingTheIconBeforeTheDelayShowsNothing() {
    var timer = DockHoverTimer<String>()
    _ = timer.hover("Safari", at: t0)
    #expect(timer.tick(inside: false, at: t0 + 0.1) == .none)
    #expect(timer.tick(inside: true, at: t0 + 0.4) == .none)
    #expect(timer.shown == nil)
  }

  @Test func anotherIconWhilePendingStartsAgain() {
    var timer = DockHoverTimer<String>()
    _ = timer.hover("Safari", at: t0)
    #expect(timer.hover("Notas", at: t0 + 0.2) == .none)
    #expect(timer.tick(inside: true, at: t0 + 0.4) == .none)
    #expect(timer.tick(inside: true, at: t0 + 0.5) == .show("Notas"))
  }

  @Test func withTheViewOpenAnotherIconSwitchesAtOnce() {
    var timer = DockHoverTimer<String>()
    _ = timer.hover("Safari", at: t0)
    _ = timer.tick(inside: true, at: t0 + 0.3)
    #expect(timer.hover("Safari", at: t0 + 0.4) == .none)
    #expect(timer.hover("Notas", at: t0 + 0.5) == .show("Notas"))
    #expect(timer.shown == "Notas")
  }

  @Test func outsideTheIconAndTheViewItHidesAfterTheMargin() {
    var timer = DockHoverTimer<String>()
    _ = timer.hover("Safari", at: t0)
    _ = timer.tick(inside: true, at: t0 + 0.3)
    #expect(timer.tick(inside: false, at: t0 + 1) == .none)
    #expect(timer.tick(inside: false, at: t0 + 1.2) == .none)
    #expect(timer.tick(inside: false, at: t0 + 1.25) == .hide)
    #expect(timer.shown == nil)
  }

  @Test func comingBackInTimeKeepsTheView() {
    var timer = DockHoverTimer<String>()
    _ = timer.hover("Safari", at: t0)
    _ = timer.tick(inside: true, at: t0 + 0.3)
    _ = timer.tick(inside: false, at: t0 + 1)
    #expect(timer.tick(inside: true, at: t0 + 1.2) == .none)
    #expect(timer.tick(inside: false, at: t0 + 1.3) == .none)
    #expect(timer.tick(inside: false, at: t0 + 1.5) == .none)
    #expect(timer.shown == "Safari")
  }

  @Test func afterCancelTheSameIconWaitsUntilTheMouseLeaves() {
    var timer = DockHoverTimer<String>()
    _ = timer.hover("Safari", at: t0)
    _ = timer.tick(inside: true, at: t0 + 0.3)
    timer.cancel()
    #expect(timer.shown == nil)
    #expect(timer.isActive)
    // El Dock repite el aviso del mismo icono: no vuelve a salir.
    #expect(timer.hover("Safari", at: t0 + 0.5) == .none)
    #expect(timer.tick(inside: true, at: t0 + 1) == .none)
    #expect(timer.shown == nil)
    // Al salir el ratón del icono, todo vuelve a empezar.
    #expect(timer.tick(inside: false, at: t0 + 1.1) == .none)
    #expect(!timer.isActive)
    _ = timer.hover("Safari", at: t0 + 2)
    #expect(timer.tick(inside: true, at: t0 + 2.2) == .none)
    #expect(timer.tick(inside: true, at: t0 + 2.3) == .show("Safari"))
  }

  @Test func afterCancelAnotherIconWaitsAsUsual() {
    var timer = DockHoverTimer<String>()
    _ = timer.hover("Safari", at: t0)
    timer.cancel()
    #expect(timer.hover("Notas", at: t0 + 0.1) == .none)
    #expect(timer.tick(inside: true, at: t0 + 0.3) == .none)
    #expect(timer.tick(inside: true, at: t0 + 0.4) == .show("Notas"))
  }

  @Test func isActiveWhilePendingOrShown() {
    var timer = DockHoverTimer<String>()
    #expect(!timer.isActive)
    _ = timer.hover("Safari", at: t0)
    #expect(timer.isActive)
    _ = timer.tick(inside: true, at: t0 + 0.3)
    #expect(timer.isActive)
    _ = timer.tick(inside: false, at: t0 + 1)
    _ = timer.tick(inside: false, at: t0 + 1.25)
    #expect(!timer.isActive)
  }
}
