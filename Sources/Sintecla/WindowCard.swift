import AppKit
import SinteclaCore
import SwiftUI

/// La tarjeta de una ventana: la miniatura (o el icono grande de la app) y, debajo, el icono pequeño y el título. La
/// comparten el selector de Alt-Tab y las vistas del Dock.
struct WindowCard: View {
  let window: SwitcherWindow
  let thumbnail: CGImage?
  let width: CGFloat
  let chosen: Bool
  /// Con los dos, la tarjeta marcada enseña cerrar y minimizar (o restaurar) arriba a la izquierda (vistas del Dock).
  var onClose: (() -> Void)?
  var onMinimize: (() -> Void)?
  /// Con él, también salir de la app, como ⌘Q.
  var onQuit: (() -> Void)?

  var body: some View {
    let icon = NSRunningApplication(processIdentifier: window.pid)?.icon ?? NSImage(named: NSImage.applicationIconName)!
    VStack(alignment: .leading, spacing: 6) {
      ZStack {
        if let thumbnail {
          Image(decorative: thumbnail, scale: 2).resizable().aspectRatio(contentMode: .fit)
            .clipShape(.rect(cornerRadius: 6))
        } else {
          Image(nsImage: icon).resizable().frame(width: 64, height: 64)
        }
      }
      .frame(width: width - 16, height: (width - 16) * 0.66)
      HStack(spacing: 6) {
        Image(nsImage: icon).resizable().frame(width: 16, height: 16)
        Text(window.label).font(.callout).lineLimit(1).truncationMode(.tail)
      }
    }
    .padding(8)
    .frame(width: width)
    .background(chosen ? Color.accentColor.opacity(0.22) : .clear, in: .rect(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, lineWidth: chosen ? 2 : 0))
    .opacity(window.isMinimized ? 0.55 : 1)
    .overlay(alignment: .topLeading) {
      if chosen, let onClose, let onMinimize {
        HStack(spacing: 6) {
          button("xmark", help: "Cerrar la ventana", action: onClose)
          button(window.isMinimized ? "arrow.up.left.and.arrow.down.right" : "minus",
                 help: window.isMinimized ? "Restaurar" : "Minimizar", action: onMinimize)
          if let onQuit { button("power", help: "Salir de \(window.appName) (⌘Q)", action: onQuit) }
        }
        .padding(5)
      }
    }
    .contentShape(.rect)
  }

  private func button(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol).font(.system(size: 11, weight: .bold)).frame(width: 24, height: 24)
        .background(.regularMaterial, in: .circle)
        .contentShape(.circle)
    }
    .buttonStyle(.plain)
    .help(help)
  }
}
