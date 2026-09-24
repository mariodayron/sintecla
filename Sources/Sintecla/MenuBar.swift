import AppKit
import SinteclaCore

/// NSMenuItem que ejecuta un closure (evita un selector por opción).
final class ClosureMenuItem: NSMenuItem {
  private let handler: () -> Void

  init(_ title: String, key: String = "", checked: Bool = false, handler: @escaping () -> Void) {
    self.handler = handler
    super.init(title: title, action: #selector(run), keyEquivalent: key)
    target = self
    state = checked ? .on : .off
  }

  @available(*, unavailable)
  required init(coder: NSCoder) { fatalError("init(coder:) no se usa") }

  @objc private func run() { handler() }
}

struct MenuActions {
  var pasteLast: () -> Void
  var addToDictionary: () -> Void
  /// Borradores de notas que quedaron sin procesar.
  var pendingNotes: () -> Int
  var showPendingNotes: () -> Void
  var showMain: () -> Void
  /// Inicio de la reunión en curso (nil si no se graba).
  var meetingSince: () -> Date?
  var toggleMeeting: () -> Void
  var pendingMeetings: () -> Int
  var showMeetings: () -> Void
  var showHistory: () -> Void
  var showSettings: () -> Void
  var showPermissions: () -> Void
  var settingsChanged: () -> Void
}

/// Icono de la barra de menú y su menú (se reconstruye cada vez que se abre).
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let settings: AppSettings
  private let actions: MenuActions
  var isReady = false

  init(settings: AppSettings, actions: MenuActions) {
    self.settings = settings
    self.actions = actions
    super.init()
    setRecording(false)
    let menu = NSMenu()
    menu.delegate = self
    statusItem.menu = menu
  }

  func setRecording(_ recording: Bool) {
    statusItem.button?.image = BrandMarkRenderer.menuImage(recording: recording)
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    menu.removeAllItems()
    let status = NSMenuItem(title: isReady ? "Sintecla: lista" : "Sintecla: faltan permisos", action: nil, keyEquivalent: "")
    status.isEnabled = false
    menu.addItem(status)
    // El micrófono lo elige macOS (Ajustes del Sistema → Sonido → Entrada); Sintecla usa ese.
    let microphone = NSMenuItem(title: "Micrófono: \(AudioDevices.defaultInputName() ?? "ninguno")",
                                action: nil, keyEquivalent: "")
    microphone.isEnabled = false
    menu.addItem(microphone)
    menu.addItem(.separator())

    let languageItem = NSMenuItem(title: "Idioma de dictado", action: nil, keyEquivalent: "")
    let languageMenu = NSMenu()
    for (code, name) in [("es_ES", "Español (España)"), ("en_US", "English (US)")] {
      languageMenu.addItem(ClosureMenuItem(name, checked: settings.language == code) { [weak self] in
        self?.settings.language = code
        self?.actions.settingsChanged()
      })
    }
    languageItem.submenu = languageMenu
    menu.addItem(languageItem)
    menu.addItem(ClosureMenuItem("Modo susurro", checked: settings.whisperMode) { [weak self] in
      guard let self else { return }
      self.settings.whisperMode.toggle()
      self.actions.settingsChanged()
    })
    let targetItem = NSMenuItem(title: "Traducir a", action: nil, keyEquivalent: "")
    let targetMenu = NSMenu()
    for target in TranslationLanguage.allCases {
      targetMenu.addItem(ClosureMenuItem(target.name, checked: settings.translationTarget == target) { [weak self] in
        self?.settings.translationTarget = target
      })
    }
    targetItem.submenu = targetMenu
    menu.addItem(targetItem)
    menu.addItem(.separator())
    if let since = actions.meetingSince() {
      let minutes = Int(Date().timeIntervalSince(since) / 60)
      menu.addItem(ClosureMenuItem("■ Detener reunión (\(minutes) min)", handler: actions.toggleMeeting))
    } else {
      menu.addItem(ClosureMenuItem("● Grabar reunión", handler: actions.toggleMeeting))
    }
    let pendingMeetings = actions.pendingMeetings()
    if pendingMeetings > 0 {
      menu.addItem(ClosureMenuItem("Reuniones pendientes (\(pendingMeetings))…", handler: actions.showMeetings))
    }
    menu.addItem(.separator())
    menu.addItem(ClosureMenuItem("Pegar último resultado", handler: actions.pasteLast))
    menu.addItem(ClosureMenuItem("Añadir selección al diccionario", handler: actions.addToDictionary))
    let pending = actions.pendingNotes()
    if pending > 0 {
      menu.addItem(ClosureMenuItem("Notas sin procesar (\(pending))…", handler: actions.showPendingNotes))
    }
    menu.addItem(ClosureMenuItem("Abrir Sintecla…", key: "o", handler: actions.showMain))
    menu.addItem(ClosureMenuItem("Historial…", handler: actions.showHistory))
    menu.addItem(ClosureMenuItem("Ajustes…", key: ",", handler: actions.showSettings))
    menu.addItem(ClosureMenuItem("Permisos…", handler: actions.showPermissions))
    menu.addItem(.separator())
    menu.addItem(ClosureMenuItem("Salir de Sintecla", key: "q") { NSApp.terminate(nil) })
  }
}
