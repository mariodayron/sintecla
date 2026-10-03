import Combine
import SinteclaCore
import SwiftUI

/// Alt-Tab → Alt-Tab (spec «Alt-Tab» §2): cómo se usa, los dos permisos y el aviso de que ⌘Tab ya es de Sintecla.
struct AltTabPage: View {
  @State private var accessibility = Permissions.accessibilityGranted
  @State private var screen = ScreenCapture.hasPermission
  private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

  var body: some View {
    Form {
      Section("Cómo se usa") {
        LabeledContent("⌘Tab", value: "Abre el selector con la ventana anterior marcada")
        LabeledContent("Tab, ⇧Tab, ← →", value: "Con ⌘ pulsado, mueven la marca")
        LabeledContent("Soltar ⌘", value: "Salta a la ventana marcada")
        LabeledContent("Esc", value: "Cierra sin cambiar nada")
        Text("También con el ratón: pasar por encima marca una ventana y un clic salta a ella. Mientras el módulo está "
             + "encendido, ⌘Tab abre el selector de Sintecla en lugar del de macOS; al apagarlo vuelve el de macOS.")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section("Permisos") {
        LabeledContent("Accesibilidad") {
          Label(accessibility ? "Dado" : "Falta", systemImage: accessibility ? "checkmark.circle.fill" : "xmark.circle")
        }
        LabeledContent("Grabación de pantalla") {
          Label(screen ? "Dado" : "Falta: sin miniaturas", systemImage: screen ? "checkmark.circle.fill" : "xmark.circle")
        }
        if !screen {
          Button("Abrir Ajustes") { ScreenCapture.openPermissionSettings() }
          Text("Sin él, el selector funciona igual, con el icono de cada app en lugar de la miniatura.")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
    }
    .formStyle(.grouped)
    .onReceive(timer) { _ in
      accessibility = Permissions.accessibilityGranted
      screen = ScreenCapture.hasPermission
    }
  }
}
