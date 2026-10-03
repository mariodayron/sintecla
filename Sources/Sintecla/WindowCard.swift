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
        WindowLights(minimized: window.isMinimized, appName: window.appName, onClose: onClose, onMinimize: onMinimize,
                     onQuit: onQuit)
          .padding(10)
      }
    }
    .contentShape(.rect)
  }
}

/// Los botones de la tarjeta, como los semáforos de una ventana de macOS: rojo cierra, amarillo minimiza (o restaura)
/// y, al lado, ⏻ en gris sale de la app. Los símbolos salen al pasar el ratón por el grupo, como en macOS.
private struct WindowLights: View {
  let minimized: Bool
  let appName: String
  let onClose: () -> Void
  let onMinimize: () -> Void
  let onQuit: (() -> Void)?
  @State private var hovering = false

  var body: some View {
    HStack(spacing: 8) {
      LightButton(color: Color(red: 1, green: 0.37, blue: 0.34), symbol: "xmark", showsSymbol: hovering,
                  help: "Cerrar la ventana", action: onClose)
      LightButton(color: Color(red: 1, green: 0.74, blue: 0.18), symbol: minimized ? "arrow.up" : "minus",
                  showsSymbol: hovering, help: minimized ? "Restaurar" : "Minimizar", action: onMinimize)
      if let onQuit {
        LightButton(color: Color(white: 0.62), symbol: "power", showsSymbol: hovering, help: "Salir de \(appName) (⌘Q)",
                    action: onQuit)
      }
    }
    .onHover { hovering = $0 }
  }
}

/// Un semáforo: se ilumina y crece un poco con el ratón encima.
private struct LightButton: View {
  let color: Color
  let symbol: String
  let showsSymbol: Bool
  let help: String
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      Circle().fill(color)
        .overlay(Circle().strokeBorder(.black.opacity(0.2), lineWidth: 0.5))
        .overlay {
          if showsSymbol {
            Image(systemName: symbol).font(.system(size: 9, weight: .heavy)).foregroundStyle(.black.opacity(0.6))
          }
        }
        .frame(width: 16, height: 16)
        .brightness(hovering ? 0.12 : 0)
        .scaleEffect(hovering ? 1.15 : 1)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .contentShape(.circle)
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
    .help(help)
  }
}
