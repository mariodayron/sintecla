import Combine
import SinteclaCore
import SwiftUI

/// Isla → Isla (spec «La isla» §2): qué enseña, si hay muesca y si la música funciona en este macOS.
struct IslandPage: View {
  private let music = NowPlayingClient.shared
  @State private var hasNotch = NotchScreen.current != nil
  private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

  var body: some View {
    Form {
      Section("Qué enseña") {
        LabeledContent("Música", value: "Carátula y onda; al pasar el ratón, la canción y sus controles")
        LabeledContent("Sintecla", value: "Dictado, reuniones y avisos, en lugar de la pastilla de abajo")
        LabeledContent("Al dictar", value: "La música se pausa y vuelve al terminar")
        Text("Al pasar el ratón por la isla con música se despliega: un clic en la carátula abre la app que suena y la "
             + "barra de progreso se puede arrastrar.")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section("Estado") {
        LabeledContent("Muesca") {
          Label(hasNotch ? "Pantalla del MacBook" : "Sin muesca: isla arriba en el centro, solo con Sintecla",
                systemImage: hasNotch ? "checkmark.circle.fill" : "macbook")
        }
        LabeledContent("Música") {
          switch music.status {
          case .ready: Label("Lista", systemImage: "checkmark.circle.fill")
          case .unavailable: Label("No disponible en este macOS", systemImage: "xmark.circle")
          case .starting, .stopped: Label("Comprobando…", systemImage: "hourglass")
          }
        }
      }
    }
    .formStyle(.grouped)
    .onReceive(timer) { _ in hasNotch = NotchScreen.current != nil }
  }
}
