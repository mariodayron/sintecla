import AppKit
import Combine
import SinteclaCore
import SwiftUI

/// Crea y muestra ventanas SwiftUI desde una app sin Dock.
@MainActor
enum WindowFactory {
  static func make<Content: View>(title: String, content: Content) -> NSWindow {
    let window = NSWindow(contentViewController: NSHostingController(rootView: content))
    window.title = title
    window.styleMask = [.titled, .closable, .miniaturizable]
    window.isReleasedWhenClosed = false
    window.center()
    return window
  }

  static func present(_ window: NSWindow) {
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
  }
}

// MARK: - Permisos

struct OnboardingView: View {
  var onContinue: () -> Void
  @State private var refresh = 0
  private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Configurar Sintecla").font(.title2.bold())
      Text("Necesita estos permisos para dictar en cualquier app.").foregroundStyle(.secondary)
      PermissionRow(title: "Micrófono", detail: "Para oír lo que dictas.",
                    granted: Permissions.microphoneGranted) {
        Task {
          if !(await Permissions.requestMicrophone()) { Permissions.open(.microphone) }
        }
      }
      PermissionRow(title: "Accesibilidad", detail: "Para detectar la tecla 🌐 y pegar el texto.",
                    granted: Permissions.accessibilityGranted) {
        Permissions.promptAccessibility()
        Permissions.open(.accessibility)
      }
      PermissionRow(title: "Monitorización de entrada", detail: "Solo si macOS la pide para leer el teclado.",
                    granted: Permissions.inputMonitoringGranted) {
        Permissions.requestInputMonitoring()
        Permissions.open(.inputMonitoring)
      }
      PermissionRow(title: "Tecla 🌐 → «No hacer nada»", detail: "Ajustes → Teclado → «Pulsar tecla 🌐 para».",
                    granted: Permissions.globeKeyDoesNothing) {
        Permissions.open(.keyboard)
      }
      if Permissions.typelessRunning {
        HStack {
          Label("Typeless está abierto y también usa 🌐.", systemImage: "exclamationmark.triangle")
            .foregroundStyle(.orange)
          Spacer()
          Button("Cerrar Typeless") { Permissions.quitTypeless() }
        }
      }
      HStack {
        Spacer()
        Button("Continuar", action: onContinue)
          .keyboardShortcut(.defaultAction)
          .disabled(!Permissions.essentialsGranted)
      }
    }
    .padding(24)
    .frame(width: 480)
    .id(refresh)  // vuelve a leer los permisos cada segundo
    .onReceive(timer) { _ in refresh += 1 }
  }
}

struct PermissionRow: View {
  let title: String
  let detail: String
  let granted: Bool
  let action: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle")
        .font(.title3)
        .foregroundStyle(granted ? .green : .red)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.headline)
        Text(detail).font(.callout).foregroundStyle(.secondary)
      }
      Spacer()
      if !granted { Button("Abrir", action: action) }
    }
  }
}

// MARK: - Ajustes

struct GeneralTab: View {
  @Bindable var settings: AppSettings
  var onChange: () -> Void

  var body: some View {
    Form {
      Toggle("Abrir Sintecla al iniciar sesión", isOn: $settings.launchAtLogin)
      Toggle("Sonidos", isOn: $settings.soundsEnabled)
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
      Section("Reuniones") {
        Toggle("Guardar también el audio de las reuniones", isOn: $settings.saveMeetingAudio)
        LabeledContent("Actas", value: "Documentos › Sintecla › Reuniones")
      }
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
    .onChange(of: settings.launchAtLogin) { onChange() }
    .onChange(of: settings.soundsEnabled) { onChange() }
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

struct DictionaryTab: View {
  @Bindable var settings: AppSettings
  @State private var newTerm = ""
  @State private var newFrom = ""
  @State private var newTo = ""

  var body: some View {
    Form {
      Section("Aprender") {
        Toggle("Aprender de mis correcciones", isOn: $settings.learnCorrections)
        Text("Tras pegar, Sintecla mira si corriges alguna palabra y la añade aquí. También puedes seleccionar una palabra "
             + "y decir «añádelo al diccionario» con Ask Anything, o usar «Añadir selección al diccionario» en el menú.")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section("Términos: nombres, marcas, jerga") {
        ForEach(settings.dictionary.terms, id: \.self) { term in
          HStack {
            Text(term)
            if settings.dictionary.learnedTerms.contains(term) { LearnedBadge() }
            Spacer()
            Button(role: .destructive) {
              settings.dictionary.remove(term: term)
            } label: { Image(systemName: "trash") }
              .buttonStyle(.borderless)
          }
        }
        HStack {
          TextField("Nuevo término", text: $newTerm)
          Button("Añadir") {
            let term = newTerm.trimmingCharacters(in: .whitespaces)
            if !settings.dictionary.terms.contains(term) { settings.dictionary.terms.append(term) }
            newTerm = ""
          }
          .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
      Section("Reemplazos exactos: lo que se oye → lo que se escribe") {
        ForEach(settings.dictionary.rules, id: \.self) { rule in
          HStack {
            Text(rule.from)
            Image(systemName: "arrow.right").foregroundStyle(.secondary)
            Text(rule.to).bold()
            if rule.learned { LearnedBadge() }
            Spacer()
            Button(role: .destructive) {
              settings.dictionary.remove(rule: rule)
            } label: { Image(systemName: "trash") }
              .buttonStyle(.borderless)
          }
        }
        HStack {
          TextField("Se oye", text: $newFrom)
          Image(systemName: "arrow.right").foregroundStyle(.secondary)
          TextField("Se escribe", text: $newTo)
          Button("Añadir") {
            settings.dictionary.rules.append(DictionaryRule(from: newFrom.trimmingCharacters(in: .whitespaces),
                                                            to: newTo.trimmingCharacters(in: .whitespaces)))
            newFrom = ""
            newTo = ""
          }
          .disabled(newFrom.trimmingCharacters(in: .whitespaces).isEmpty || newTo.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
    }
    .formStyle(.grouped)
  }
}

/// Etiqueta de lo que el diccionario aprendió solo.
struct LearnedBadge: View {
  var body: some View {
    Text("aprendido")
      .font(.caption2.weight(.medium))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 6)
      .padding(.vertical, 1)
      .background(.quaternary, in: Capsule())
  }
}

struct TonesTab: View {
  @Bindable var settings: AppSettings
  /// Dominio de la pestaña de delante de Safari (se relee al volver a la ventana).
  @State private var openSite: String?
  @State private var newSite = ""

  var body: some View {
    Form {
      Section("Tono por app") {
        ForEach(sortedIDs, id: \.self) { id in
          Picker(appName(id), selection: binding(for: id)) {
            ForEach(Tone.allCases, id: \.self) { Text($0.label).tag($0) }
          }
        }
      }
      Section {
        Menu("Añadir una app abierta…") {
          ForEach(runningAppIDs, id: \.self) { id in
            Button(appName(id)) { settings.tones.byBundleID[id] = .neutral }
          }
        }
      }
      Section("Tono por web (Safari)") {
        ForEach(settings.tones.bySite.keys.sorted(), id: \.self) { site in
          HStack {
            Picker(site, selection: siteBinding(for: site)) {
              ForEach(Tone.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            Button(role: .destructive) {
              settings.tones.bySite[site] = nil
            } label: { Image(systemName: "trash") }
              .buttonStyle(.borderless)
          }
        }
      }
      Section {
        Button(openSite.map { "Añadir la web abierta en Safari (\($0))" } ?? "Añadir la web abierta en Safari") {
          if let openSite { settings.tones.bySite[openSite] = .neutral }
        }
        .disabled(openSite.map { settings.tones.bySite[$0] != nil } ?? true)
        HStack {
          TextField("Otra web", text: $newSite, prompt: Text("p. ej. linkedin.com"))
            .onSubmit(addNewSite)
          Button("Añadir", action: addNewSite)
            .disabled(SiteRules.normalize(newSite).map { settings.tones.bySite[$0] != nil } ?? true)
        }
      }
    }
    .formStyle(.grouped)
    .task { openSite = await SafariSite.frontTab() }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
      Task { openSite = await SafariSite.frontTab() }
    }
  }

  private func addNewSite() {
    guard let site = SiteRules.normalize(newSite), settings.tones.bySite[site] == nil else { return }
    settings.tones.bySite[site] = .neutral
    newSite = ""
  }

  private func siteBinding(for site: String) -> Binding<Tone> {
    Binding(get: { settings.tones.bySite[site] ?? .neutral },
            set: { settings.tones.bySite[site] = $0 })
  }

  private var sortedIDs: [String] {
    settings.tones.byBundleID.keys.sorted { appName($0).localizedCaseInsensitiveCompare(appName($1)) == .orderedAscending }
  }

  private var runningAppIDs: [String] {
    NSWorkspace.shared.runningApplications
      .filter { $0.activationPolicy == .regular }
      .compactMap(\.bundleIdentifier)
      .filter { settings.tones.byBundleID[$0] == nil }
      .sorted()
  }

  private func binding(for id: String) -> Binding<Tone> {
    Binding(get: { settings.tones.byBundleID[id] ?? .neutral },
            set: { settings.tones.byBundleID[id] = $0 })
  }

  private func appName(_ id: String) -> String {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return id }
    return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
  }
}

struct AITab: View {
  @Bindable var settings: AppSettings
  let history: HistoryStore
  @State private var keyField = ""
  @State private var status = ""
  @State private var testing = false
  @State private var learning = false
  @State private var styleStatus = ""
  @State private var draft: StyleDraft?

  var body: some View {
    Form {
      Section("Gemini: dictado, Ask Anything, notas y respaldo de la traducción") {
        LabeledContent("Clave", value: settings.geminiKey.isEmpty ? "Sin clave" : "Guardada en el Llavero ✓")
        SecureField("Pega aquí tu clave de Google AI Studio", text: $keyField)
        HStack {
          Button("Guardar clave") {
            status = settings.setGeminiKey(keyField) ? "Clave guardada" : "No se pudo guardar en el Llavero"
            keyField = ""
          }
          .disabled(keyField.trimmingCharacters(in: .whitespaces).isEmpty)
          Button("Borrar clave", role: .destructive) {
            settings.setGeminiKey("")
            status = "Clave borrada"
          }
          .disabled(settings.geminiKey.isEmpty)
          Spacer()
          Button("Probar conexión", action: test)
            .disabled(settings.geminiKey.isEmpty || testing)
        }
        if !status.isEmpty {
          Text(status).font(.callout).foregroundStyle(.secondary)
        }
        TextField("Modelo", text: $settings.geminiModel)
        Toggle("Ordenar el dictado con Gemini", isOn: $settings.cleanWithGemini)
          .disabled(settings.geminiKey.isEmpty)
        Text("Tus dictados se envían a Gemini para ordenarlos. Sin clave, sin conexión o apagado, se ordenan en el Mac.")
          .font(.caption).foregroundStyle(.secondary)
        Link("Crear una clave en Google AI Studio", destination: URL(string: "https://aistudio.google.com/apikey")!)
      }
      Section("Mi estilo") {
        TextField("Ej.: tuteo, frases cortas, sin emojis", text: $settings.myStyle, axis: .vertical)
          .lineLimit(1...5)
        Text("Se añade a las instrucciones de edición (Ask Anything), notas y actas.")
          .font(.caption).foregroundStyle(.secondary)
        HStack {
          Button("Aprender de mi historial", action: learnStyle)
            .disabled(settings.geminiKey.isEmpty || learning)
          if learning {
            ProgressView().controlSize(.small)
            Text("Leyendo tus dictados…").foregroundStyle(.secondary)
          }
        }
        if settings.geminiKey.isEmpty {
          Text("Necesita la clave de Gemini").font(.caption).foregroundStyle(.secondary)
        }
        if !styleStatus.isEmpty {
          Text(styleStatus).font(.callout).foregroundStyle(.secondary)
        }
      }
    }
    .formStyle(.grouped)
    .sheet(item: $draft) { draft in
      StyleProposalSheet(text: draft.text, used: draft.used) { settings.myStyle = $0 }
    }
  }

  /// Gemini propone "Mi estilo" a partir de los últimos dictados; no cambia nada hasta Guardar.
  private func learnStyle() {
    guard let model = settings.cloudModel(timeout: 60) else { return }
    learning = true
    styleStatus = ""
    let entries = history.load()
    let current = settings.myStyle
    Task {
      do {
        let proposal = try await StyleLearner.learn(from: entries, currentStyle: current, model: model)
        draft = StyleDraft(text: proposal.style, used: proposal.used)
      } catch let failure as StyleLearner.Failure {
        styleStatus = failure.message
      } catch {
        styleStatus = (error as? CloudError)?.userMessage ?? error.localizedDescription
      }
      learning = false
    }
  }

  private func test() {
    guard let model = settings.cloudModel() else { return }
    testing = true
    status = "Probando…"
    Task {
      let start = Date()
      do {
        _ = try await model.complete(instructions: "Responde solo con la palabra OK.", prompt: "ping")
        status = String(format: "Conexión correcta (%.1f s)", Date().timeIntervalSince(start))
      } catch {
        status = (error as? CloudError)?.userMessage ?? error.localizedDescription
      }
      testing = false
    }
  }
}

struct StyleDraft: Identifiable {
  let id = UUID()
  var text: String
  var used: Int
}

/// Propuesta de "Mi estilo", editable antes de guardarla.
struct StyleProposalSheet: View {
  @State var text: String
  let used: Int
  var onSave: (String) -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Tu estilo, según tus dictados").font(.headline)
      TextEditor(text: $text)
        .font(.body)
        .scrollContentBackground(.hidden)
        .padding(6)
        .frame(minHeight: 120)
        .background(.quaternary, in: .rect(cornerRadius: 8))
      Text("Basado en tus últimos \(used) dictados, enviados a Gemini.")
        .font(.caption).foregroundStyle(.secondary)
      HStack {
        Spacer()
        Button("Cancelar") { dismiss() }
          .keyboardShortcut(.cancelAction)
        Button("Guardar") {
          onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 460)
  }
}

// MARK: - Historial

struct HistoryView: View {
  let store: HistoryStore
  @State private var entries: [HistoryEntry] = []
  @State private var query = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      TextField("Buscar", text: $query).textFieldStyle(.roundedBorder)
      List(filtered) { entry in
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
            Text(entry.appName ?? "—")
            Spacer()
            Button("Copiar") {
              NSPasteboard.general.clearContents()
              NSPasteboard.general.setString(entry.finalText, forType: .string)
            }
            .buttonStyle(.borderless)
          }
          .font(.caption)
          .foregroundStyle(.secondary)
          Text(entry.finalText).textSelection(.enabled)
        }
        .padding(.vertical, 2)
      }
    }
    .padding()
    .onAppear { entries = store.load() }
  }

  private var filtered: [HistoryEntry] {
    query.isEmpty ? entries : entries.filter { $0.finalText.localizedCaseInsensitiveContains(query) }
  }
}
