import AppKit
import SwiftUI

/// El panel de la isla: transparente, encima de la barra de menús y pegado arriba, centrado en la muesca. No activa
/// Sintecla, y solo recibe el ratón cuando el controlador se lo pide (con el ratón dentro de la isla): así la barra de
/// menús de alrededor sigue funcionando.
@MainActor
final class IslandPanel {
  /// Cabe la isla más grande (desplegada) con su sombra, y la burbuja al lado.
  static let size = CGSize(width: 760, height: 240)

  private let panel: NSPanel

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
    panel.contentView = FirstMouseHostingView(rootView: view)
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
