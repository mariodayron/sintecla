import SwiftUI

/// Herramientas (spec «Herramientas» §3): utilidades de Windows o de apps de pago, cada una con su interruptor
/// y todas apagadas por defecto.
struct ToolsTab: View {
  @Bindable var settings: AppSettings

  var body: some View {
    Form {
      Section("Finder") {
        Toggle("Cortar y pegar archivos (⌘X, ⌘V)", isOn: $settings.finderCut)
        Text("⌘X corta los archivos seleccionados y ⌘V los mueve a la carpeta abierta, como en Windows. "
             + "Al renombrar, ⌘X corta texto como siempre.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }
}
