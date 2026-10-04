import AppKit
import SwiftUI

/// El panel de la isla: transparente, encima de la barra de menús y pegado arriba, centrado en la muesca. No activa
/// Sintecla, y solo recibe el ratón cuando el controlador se lo pide (con el ratón dentro de la isla): así la barra de
/// menús de alrededor sigue funcionando.
@MainActor
final class IslandPanel {
  /// Cabe la isla más grande (desplegada con música y estante) con su sombra, y la burbuja al lado.
  static let size = CGSize(width: 760, height: 300)

  private let panel: NSPanel
  /// Recibe los archivos cuando la isla es la bandeja (spec «Estante y avisos» §3.1).
  let dropView = FileDropView(frame: NSRect(origin: .zero, size: IslandPanel.size))

  init(view: IslandView) {
    panel = NSPanel(contentRect: NSRect(origin: .zero, size: Self.size), styleMask: [.nonactivatingPanel, .borderless],
                    backing: .buffered, defer: false)
    // Por encima de la barra de menús.
    panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    let hosting = FirstMouseHostingView(rootView: view)
    hosting.frame = dropView.bounds
    hosting.autoresizingMask = [.width, .height]
    dropView.addSubview(hosting)
    dropView.accepting = false
    panel.contentView = dropView
  }

  var acceptsMouse: Bool {
    get { !panel.ignoresMouseEvents }
    set { if panel.ignoresMouseEvents == newValue { panel.ignoresMouseEvents = !newValue } }
  }

  /// Pegado arriba de la pantalla y centrado en la muesca.
  func show(on screen: NSScreen, notch: CGRect) {
    let frame = NSRect(x: notch.midX - Self.size.width / 2, y: screen.frame.maxY - Self.size.height,
                       width: Self.size.width, height: Self.size.height)
    if panel.frame != frame { panel.setFrame(frame, display: true) }
    panel.orderFrontRegardless()
  }

  func hide() {
    acceptsMouse = false
    panel.orderOut(nil)
  }
}
