import SinteclaCore
import SwiftUI

/// Capturas → Capturas (spec «Capturas» §2.1 y §2.2): el permiso, los atajos y el aviso si macOS aún usa ⇧⌘3 o ⇧⌘4.
struct CapturesPage: View {
  @State private var permission = ScreenCapture.hasPermission
  @State private var macOSShortcuts = ScreenCapture.macOSShortcutsActive
  private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

  var body: some View {
    Form {
      Section("Permiso") {
        LabeledContent("Grabación de pantalla") {
          Label(permission ? "Dado" : "Falta", systemImage: permission ? "checkmark.circle.fill" : "xmark.circle")
        }
        if !permission {
          HStack {
            Button("Dar permiso…") { ScreenCapture.requestPermission() }
            Button("Abrir Ajustes") { ScreenCapture.openPermissionSettings() }
          }
          Text("Sin él, macOS entrega capturas vacías. Después de darlo, sal de Sintecla y vuelve a abrirla.")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      Section("Atajos") {
        ForEach(CaptureAction.allCases, id: \.self) { action in
          LabeledContent(action.title, value: action.shortcut)
        }
        Text("⇧⌘3 y ⇧⌘4 copian la captura al portapapeles. ⇧⌘2 copia el texto de una zona o el contenido de un QR; "
             + "⇧⌘1, además, abre una tarjeta para traducirlo o preguntar. Mientras el módulo está encendido, estos "
             + "atajos no llegan a otras apps.")
          .font(.caption).foregroundStyle(.secondary)
      }
      if macOSShortcuts {
        Section {
          Label("macOS también usa ⇧⌘3 o ⇧⌘4: desactívalos en Ajustes → Teclado → Atajos de teclado → Capturas de "
                + "pantalla.", systemImage: "exclamationmark.triangle")
          Button("Abrir los atajos de teclado") { ScreenCapture.openKeyboardShortcuts() }
        }
      }
    }
    .formStyle(.grouped)
    .onReceive(timer) { _ in
      permission = ScreenCapture.hasPermission
      macOSShortcuts = ScreenCapture.macOSShortcutsActive
    }
  }
}
