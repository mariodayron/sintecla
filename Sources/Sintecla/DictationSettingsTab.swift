import SinteclaCore
import SwiftUI

/// Dictado → Atajos e idioma: lo que era del dictado en General hasta la 0.9.0.
struct DictationSettingsTab: View {
  @Bindable var settings: AppSettings
  var onChange: () -> Void

  var body: some View {
    Form {
      Toggle("Modo susurro (más ganancia de micrófono)", isOn: $settings.whisperMode)
      Picker("Idioma de dictado", selection: $settings.language) {
        Text("Español (España)").tag("es_ES")
        Text("English (US)").tag("en_US")
      }
      Picker("Traducir a", selection: $settings.translationTarget) {
        ForEach(TranslationLanguage.allCases, id: \.self) { Text($0.name).tag($0) }
      }
      Picker("Tecla base", selection: $settings.baseKey) {
        Text("🌐 Fn").tag(BaseKey.fn)
        Text("⌥ derecha").tag(BaseKey.rightOption)
        Text("Las dos (🌐 o ⌥ derecha)").tag(BaseKey.both)
      }
      Text("Algunos teclados externos (p. ej. Logitech) no envían su tecla Fn al Mac: con ellos usa ⌥ derecha.")
        .font(.caption).foregroundStyle(.secondary)
      Section("Atajos (mantener, o pulsar para manos libres)") {
        LabeledContent("Dictar", value: settings.hotkeys.shortcut(for: .dictation, baseKey: settings.baseKey) ?? "")
        ForEach(HotkeyLayout.configurableModes, id: \.self) { mode in
          VStack(alignment: .leading, spacing: 2) {
            Picker(mode == .meeting ? "Reunión (empieza o termina)" : mode.name, selection: companion(for: mode)) {
              ForEach(HotkeyCompanion.allCases, id: \.self) { Text($0.name).tag($0) }
            }
            Text(settings.hotkeys.shortcut(for: mode, baseKey: settings.baseKey) ?? "Sin atajo")
              .font(.caption).foregroundStyle(.secondary)
            if let warning = settings.hotkeys.warning(for: mode, baseKey: settings.baseKey) {
              Text(warning).font(.caption).foregroundStyle(.secondary)
            }
          }
        }
        LabeledContent("Cancelar / cerrar tarjeta", value: "Esc")
        Button("Restaurar atajos") { settings.hotkeys = .defaults }
          .disabled(settings.hotkeys == .defaults)
      }
    }
    .formStyle(.grouped)
    .onChange(of: settings.language) { onChange() }
    .onChange(of: settings.baseKey) { onChange() }
    .onChange(of: settings.hotkeys) { onChange() }
  }

  /// Elegir una tecla que ya tiene otro modo las intercambia.
  private func companion(for mode: HotkeyMode) -> Binding<HotkeyCompanion> {
    Binding(get: { settings.hotkeys.companion(for: mode) ?? .shift },
            set: { settings.hotkeys.assign($0, to: mode) })
  }
}
