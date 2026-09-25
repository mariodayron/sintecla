import AppKit
import Observation
import SinteclaCore
import SwiftUI

@MainActor @Observable
final class MainNavigation {
  var place: WindowPlace = .home
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

/// Ventana principal (spec «Módulos y batería» §3.1): Inicio con una tarjeta por módulo; dentro de un módulo, barra
/// lateral de Liquid Glass (nativa en macOS 26) solo con sus páginas.
struct MainView: View {
  @Bindable var navigation: MainNavigation
  @Bindable var settings: AppSettings
  let history: HistoryStore
  let usage: UsageStatsStore
  let meetings: MeetingLibrary
  let meetingActions: MeetingActions
  var showPermissions: () -> Void
  var onSettingsChange: () -> Void

  var body: some View {
    let place = navigation.place.resolved(with: settings.modules)
    Group {
      if let module = place.module {
        NavigationSplitView {
          sidebar(module)
        } detail: {
          detail(place)
        }
      } else {
        NavigationStack { detail(place) }
      }
    }
    .frame(minWidth: 820, minHeight: 560)
    .tint(.gray)  // sin colores: selección, interruptores y botones en gris neutro
  }

  private func sidebar(_ module: Module) -> some View {
    List(selection: pageSelection) {
      Button { navigation.place = .home } label: { Label("Inicio", systemImage: "chevron.backward") }
        .buttonStyle(.plain)
      Section(module.name) {
        ForEach(module.pages, id: \.self) { page in
          Label(page.title, systemImage: page.symbol).tag(page)
        }
      }
    }
    .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
  }

  private var pageSelection: Binding<ModulePage?> {
    Binding(get: { if case .page(let page) = navigation.place { page } else { nil } },
            set: { if let page = $0 { navigation.place = .page(page) } })
  }

  @ViewBuilder private func detail(_ place: WindowPlace) -> some View {
    switch place {
    case .home:
      HomeView(settings: settings, usage: usage, meetings: meetings, meetingActions: meetingActions, navigation: navigation)
        .navigationTitle("Sintecla")
    case .general:
      GeneralTab(settings: settings, showPermissions: showPermissions, onChange: onSettingsChange)
        .navigationTitle("General")
        .toolbar { backHome }
    case .modules:
      ModulesView(settings: settings)
        .navigationTitle("Módulos")
        .toolbar { backHome }
    case .page(let page):
      pageView(page).navigationTitle(page.title)
    }
  }

  private var backHome: some ToolbarContent {
    ToolbarItem(placement: .navigation) {
      Button { navigation.place = .home } label: { Label("Inicio", systemImage: "chevron.backward") }
    }
  }

  @ViewBuilder private func pageView(_ page: ModulePage) -> some View {
    switch page {
    case .history: HistoryView(store: history)
    case .stats: StatsView(store: usage)
    case .dictionary: DictionaryTab(settings: settings)
    case .tones: TonesTab(settings: settings)
    case .ai: AITab(settings: settings, history: history)
    case .hotkeys: DictationSettingsTab(settings: settings, onChange: onSettingsChange)
    case .meetings: MeetingsPage(library: meetings, actions: meetingActions, settings: settings)
    case .finderCut: FinderCutPage()
    }
  }
}

/// Reuniones → Reuniones: la lista y, abajo, dónde se guardan y si se guarda también el audio.
struct MeetingsPage: View {
  let library: MeetingLibrary
  let actions: MeetingActions
  @Bindable var settings: AppSettings

  var body: some View {
    VStack(spacing: 0) {
      MeetingsView(library: library, actions: actions)
      Divider()
      HStack {
        Toggle("Guardar también el audio de las reuniones", isOn: $settings.saveMeetingAudio)
        Spacer()
        Text("Actas en Documentos › Sintecla › Reuniones").font(.caption).foregroundStyle(.secondary)
      }
      .padding(.horizontal, 16).padding(.vertical, 10)
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

  func show(_ place: WindowPlace? = nil) {
    if let place { navigation.place = place }
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
