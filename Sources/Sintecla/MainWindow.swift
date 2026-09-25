import AppKit
import Observation
import SinteclaCore
import SwiftUI

enum MainSection: String, Hashable {
  case meetings, history, stats, general, dictionary, tones, ai, tools
}

@MainActor @Observable
final class MainNavigation {
  var section: MainSection? = .meetings
}

/// Lista de reuniones que ve la ventana (se recarga cuando una reunión cambia de estado).
@MainActor @Observable
final class MeetingLibrary {
  let store: MeetingStore
  private(set) var records: [MeetingRecord] = []
  /// Reunión en curso: su inicio (para el cronómetro); nil si no se graba.
  var recordingSince: Date?

  init(store: MeetingStore) {
    self.store = store
    reload()
  }

  func reload() {
    records = store.all()
  }
}

struct MeetingActions {
  var toggle: () -> Void
  var retry: (MeetingRecord) -> Void
}

/// Ventana principal: barra lateral de Liquid Glass (nativa en macOS 26) con Reuniones, Historial, Estadísticas y Ajustes.
struct MainView: View {
  @Bindable var navigation: MainNavigation
  @Bindable var settings: AppSettings
  let history: HistoryStore
  let usage: UsageStatsStore
  let meetings: MeetingLibrary
  let meetingActions: MeetingActions
  var onSettingsChange: () -> Void

  var body: some View {
    NavigationSplitView {
      List(selection: $navigation.section) {
        Label("Reuniones", systemImage: "person.2.wave.2").tag(MainSection.meetings)
        Label("Historial", systemImage: "clock.arrow.circlepath").tag(MainSection.history)
        Label("Estadísticas", systemImage: "chart.bar").tag(MainSection.stats)
        Section("Ajustes") {
          Label("General", systemImage: "gearshape").tag(MainSection.general)
          Label("Diccionario", systemImage: "book").tag(MainSection.dictionary)
          Label("Tonos", systemImage: "textformat").tag(MainSection.tones)
          Label("IA", systemImage: "sparkles").tag(MainSection.ai)
          Label("Herramientas", systemImage: "wrench.and.screwdriver").tag(MainSection.tools)
        }
      }
      .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
    } detail: {
      detail
    }
    .frame(minWidth: 820, minHeight: 560)
    .tint(.gray)  // sin colores: selección, interruptores y botones en gris neutro
  }

  @ViewBuilder private var detail: some View {
    switch navigation.section ?? .meetings {
    case .meetings: MeetingsView(library: meetings, actions: meetingActions).navigationTitle("Reuniones")
    case .history: HistoryView(store: history).navigationTitle("Historial")
    case .stats: StatsView(store: usage).navigationTitle("Estadísticas")
    case .general: GeneralTab(settings: settings, onChange: onSettingsChange).navigationTitle("General")
    case .dictionary: DictionaryTab(settings: settings).navigationTitle("Diccionario")
    case .tones: TonesTab(settings: settings).navigationTitle("Tonos")
    case .ai: AITab(settings: settings, history: history).navigationTitle("IA")
    case .tools: ToolsTab(settings: settings).navigationTitle("Herramientas")
    }
  }
}

struct MeetingsView: View {
  let library: MeetingLibrary
  let actions: MeetingActions

  var body: some View {
    Group {
      if library.records.isEmpty {
        ContentUnavailableView {
          Label("Tus reuniones", systemImage: "person.2.wave.2")
        } description: {
          Text("Graba una videollamada: Sintecla transcribe tu voz y la de los demás y te deja el acta en PDF.")
        } actions: {
          recordButton
        }
      } else {
        List(library.records) { record in
          MeetingRow(record: record, recordingSince: record.status == .recording ? library.recordingSince : nil,
                     onRetry: { actions.retry(record) }, onDelete: {
                       try? library.store.delete(record.id)
                       library.reload()
                     })
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: library.records)
      }
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) { recordButton }
    }
  }

  private var recordButton: some View {
    Button(action: actions.toggle) {
      Label(library.recordingSince == nil ? "Grabar reunión" : "Detener",
            systemImage: library.recordingSince == nil ? "record.circle" : "stop.circle.fill")
        .contentTransition(.symbolEffect(.replace))
    }
    .buttonStyle(.glass)
  }
}

struct MeetingRow: View {
  let record: MeetingRecord
  let recordingSince: Date?
  var onRetry: () -> Void
  var onDelete: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: record.status == .ready ? "doc.richtext" : "waveform")
        .font(.title2)
        .foregroundStyle(.secondary)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 2) {
        Text(record.title ?? "Reunión").font(.headline)
        Text(detail).font(.subheadline).foregroundStyle(.secondary)
      }
      Spacer()
      badge
      switch record.status {
      case .ready: Button("Abrir PDF") { open(record.pdfPath) }.buttonStyle(.glass)
      case .pending: Button("Reintentar", action: onRetry).buttonStyle(.glass)
      default: EmptyView()
      }
    }
    .padding(.vertical, 6)
    .contentShape(Rectangle())
    .onTapGesture(count: 2) { open(record.pdfPath) }
    .contextMenu {
      if record.pdfPath != nil { Button("Abrir PDF") { open(record.pdfPath) } }
      if record.markdownPath != nil { Button("Abrir Markdown") { open(record.markdownPath) } }
      if let path = record.pdfPath {
        Button("Mostrar en el Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
      }
      if record.status != .recording { Divider(); Button("Borrar", role: .destructive, action: onDelete) }
    }
  }

  private var detail: String {
    var parts = [record.startedAt.formatted(date: .abbreviated, time: .shortened)]
    if record.duration > 0 { parts.append("\(max(1, Int((record.duration / 60).rounded()))) min") }
    if record.tasks > 0 { parts.append("\(record.tasks) tareas") }
    if record.status == .pending, let problem = record.problem { parts.append(problem) }
    return parts.joined(separator: " · ")
  }

  @ViewBuilder private var badge: some View {
    switch record.status {
    case .recording:
      HStack(spacing: 6) {
        Image(systemName: "record.circle.fill")
        if let since = recordingSince {
          TimelineView(.periodic(from: since, by: 1)) { context in
            Text(OverlayView.clock(context.date.timeIntervalSince(since))).monospacedDigit()
          }
        } else {
          Text("Grabando")
        }
      }
      .modifier(StatusBadge())
    case .processing:
      HStack(spacing: 6) { ProgressView().controlSize(.mini); Text("Procesando") }.modifier(StatusBadge())
    case .ready: Label("Lista", systemImage: "checkmark").modifier(StatusBadge())
    case .pending: Label("Pendiente", systemImage: "exclamationmark.circle").modifier(StatusBadge())
    }
  }

  private func open(_ path: String?) {
    guard let path else { return }
    NSWorkspace.shared.open(URL(fileURLWithPath: path))
  }
}

/// Cápsula de cristal sin color: el estado se distingue por el icono.
struct StatusBadge: ViewModifier {
  func body(content: Content) -> some View {
    content
      .font(.system(.caption, design: .rounded).weight(.medium))
      .padding(.horizontal, 10).padding(.vertical, 4)
      .glassEffect(.regular, in: .capsule)
  }
}

/// La ventana principal. Mientras está abierta, Sintecla aparece en el Dock; al cerrarla vuelve a vivir solo en la
/// barra de menú.
@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
  let navigation = MainNavigation()
  private var window: NSWindow?
  private let makeContent: (MainNavigation) -> AnyView

  init(makeContent: @escaping (MainNavigation) -> AnyView) {
    self.makeContent = makeContent
  }

  func show(_ section: MainSection? = nil) {
    if let section { navigation.section = section }
    if window == nil {
      let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 920, height: 620),
                            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                            backing: .buffered, defer: false)
      window.title = "Sintecla"
      window.isReleasedWhenClosed = false
      window.contentView = NSHostingView(rootView: makeContent(navigation))
      window.delegate = self
      window.center()
      window.setFrameAutosaveName("SinteclaMain")
      self.window = window
    }
    NSApp.setActivationPolicy(.regular)
    NSApp.activate()
    window?.makeKeyAndOrderFront(nil)
  }

  func windowWillClose(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
  }
}

/// Menú de la app: lo ves con la ventana abierta y, además, hace que ⌘C, ⌘V y ⌘Z funcionen en los campos de texto.
@MainActor
enum MainMenu {
  static func make(showSettings: @escaping () -> Void) -> NSMenu {
    let menu = NSMenu()
    let appItem = NSMenuItem()
    let appMenu = NSMenu(title: "Sintecla")
    appMenu.addItem(ClosureMenuItem("Ajustes…", key: ",", handler: showSettings))
    appMenu.addItem(.separator())
    appMenu.addItem(NSMenuItem(title: "Ocultar Sintecla", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
    appMenu.addItem(NSMenuItem(title: "Salir de Sintecla", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    appItem.submenu = appMenu
    menu.addItem(appItem)

    let editItem = NSMenuItem()
    let edit = NSMenu(title: "Edición")
    edit.addItem(NSMenuItem(title: "Deshacer", action: Selector(("undo:")), keyEquivalent: "z"))
    edit.addItem(NSMenuItem(title: "Rehacer", action: Selector(("redo:")), keyEquivalent: "Z"))
    edit.addItem(.separator())
    edit.addItem(NSMenuItem(title: "Cortar", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
    edit.addItem(NSMenuItem(title: "Copiar", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
    edit.addItem(NSMenuItem(title: "Pegar", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
    edit.addItem(NSMenuItem(title: "Seleccionar todo", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
    editItem.submenu = edit
    menu.addItem(editItem)

    let windowItem = NSMenuItem()
    let windowMenu = NSMenu(title: "Ventana")
    windowMenu.addItem(NSMenuItem(title: "Cerrar", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
    windowMenu.addItem(NSMenuItem(title: "Minimizar", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
    windowItem.submenu = windowMenu
    menu.addItem(windowItem)
    return menu
  }
}
