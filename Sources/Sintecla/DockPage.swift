import Combine
import SinteclaCore
import SwiftUI

/// Dock → Dock (spec «Vistas del Dock» §2): cómo se usa, los dos permisos y el aviso de cerrar otras apps que hacen lo
/// mismo.
struct DockPage: View {
  @State private var accessibility = Permissions.accessibilityGranted
  @State private var screen = ScreenCapture.hasPermission
  private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

  var body: some View {
    Form {
      Section("Cómo se usa") {
        LabeledContent("Pasar el ratón", value: "Por una app abierta del Dock: salen sus ventanas")
        LabeledContent("Clic en una ventana", value: "La pone delante (y la restaura si estaba minimizada)")
        LabeledContent("Botones de la tarjeta", value: "Cerrar la ventana, o minimizarla y restaurarla")
        LabeledContent("Esc", value: "Cierra la vista")
        Text("Si usas DockDoor u otra app que enseña las ventanas al pasar por el Dock, ciérrala: si no, saldrán dos "
             + "vistas a la vez.")
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
          Text("Sin él, la vista funciona igual, con el icono de la app en lugar de la miniatura.")
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
