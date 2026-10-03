import Foundation

/// Los módulos de Sintecla (spec «Módulos y batería» §2). Cada uno se enciende o se apaga en la página Módulos.
public enum Module: String, CaseIterable, Sendable {
  case dictation, meetings, finder, captures, altTab, dock, island, remote

  public var name: String {
    switch self {
    case .dictation: "Dictado"
    case .meetings: "Reuniones"
    case .finder: "Finder"
    case .captures: "Capturas"
    case .altTab: "Alt-Tab"
    case .dock: "Dock"
    case .island: "Isla"
    case .remote: "Mando"
    }
  }

  public var symbol: String {
    switch self {
    case .dictation: "waveform"
    case .meetings: "person.2.wave.2"
    case .finder: "folder"
    case .captures: "camera.viewfinder"
    case .altTab: "rectangle.on.rectangle"
    case .dock: "dock.rectangle"
    case .island: "capsule.tophalf.filled"
    case .remote: "iphone.radiowaves.left.and.right"
    }
  }

  /// Lo que hace, para la página Módulos.
  public var detail: String {
    switch self {
    case .dictation: "Dictado, traducción, Ask Anything y notas con la tecla base."
    case .meetings: "Graba videollamadas y te deja el acta en PDF."
    case .finder: "⌘X corta los archivos seleccionados y ⌘V los mueve a la carpeta abierta, como en Windows."
    case .captures: "⇧⌘3 pantalla, ⇧⌘4 zona, ⇧⌘2 texto y ⇧⌘1 texto con traducir y preguntar. Necesita el permiso de "
      + "Grabación de pantalla."
    case .altTab: "⌘Tab cambia de ventana, no de app, con una miniatura de cada una, como en Windows. Las miniaturas "
      + "necesitan el permiso de Grabación de pantalla."
    case .dock: "Al pasar el ratón por una app del Dock, enseña sus ventanas para saltar a una, cerrarla o minimizarla. "
      + "Las miniaturas necesitan el permiso de Grabación de pantalla."
    case .island: "La muesca del MacBook cobra vida, como la Dynamic Island: la música que suena y el dictado, las "
      + "reuniones y los avisos de Sintecla. Al dictar, la música se pausa."
    case .remote: "El móvil como trackpad y mando del Mac: abre en él el enlace del QR, en la misma Wi-Fi, sin instalar "
      + "nada. Se enciende y se apaga desde la barra de menús."
    }
  }

  /// Las páginas del módulo en la barra lateral, en orden.
  public var pages: [ModulePage] { ModulePage.allCases.filter { $0.module == self } }
}

public enum ModulePage: String, CaseIterable, Hashable, Sendable {
  case history, stats, dictionary, tones, ai, hotkeys
  case meetings
  case finderCut
  case captures
  case altTab
  case dock
  case island
  case remote

  public var module: Module {
    switch self {
    case .history, .stats, .dictionary, .tones, .ai, .hotkeys: .dictation
    case .meetings: .meetings
    case .finderCut: .finder
    case .captures: .captures
    case .altTab: .altTab
    case .dock: .dock
    case .island: .island
    case .remote: .remote
    }
  }

  public var title: String {
    switch self {
    case .history: "Historial"
    case .stats: "Estadísticas"
    case .dictionary: "Diccionario"
    case .tones: "Tonos"
    case .ai: "IA"
    case .hotkeys: "Atajos e idioma"
    case .meetings: "Reuniones"
    case .finderCut: "Cortar y pegar"
    case .captures: "Capturas"
    case .altTab: "Alt-Tab"
    case .dock: "Dock"
    case .island: "Isla"
    case .remote: "Mando"
    }
  }

  public var symbol: String {
    switch self {
    case .history: "clock.arrow.circlepath"
    case .stats: "chart.bar"
    case .dictionary: "book"
    case .tones: "textformat"
    case .ai: "sparkles"
    case .hotkeys: "keyboard"
    case .meetings: "person.2.wave.2"
    case .finderCut: "scissors"
    case .captures: "camera.viewfinder"
    case .altTab: "rectangle.on.rectangle"
    case .dock: "dock.rectangle"
    case .island: "capsule.tophalf.filled"
    case .remote: "iphone.radiowaves.left.and.right"
    }
  }
}

/// Qué módulos están encendidos.
public struct ModuleSwitches: Equatable, Sendable {
  public var dictation: Bool
  public var meetings: Bool
  public var finder: Bool
  public var captures: Bool
  public var altTab: Bool
  public var dock: Bool
  public var island: Bool
  public var remote: Bool

  public init(dictation: Bool, meetings: Bool, finder: Bool, captures: Bool = false, altTab: Bool = false,
              dock: Bool = false, island: Bool = false, remote: Bool = false) {
    self.dictation = dictation
    self.meetings = meetings
    self.finder = finder
    self.captures = captures
    self.altTab = altTab
    self.dock = dock
    self.island = island
    self.remote = remote
  }

  public subscript(module: Module) -> Bool {
    get {
      switch module {
      case .dictation: dictation
      case .meetings: meetings
      case .finder: finder
      case .captures: captures
      case .altTab: altTab
      case .dock: dock
      case .island: island
      case .remote: remote
      }
    }
    set {
      switch module {
      case .dictation: dictation = newValue
      case .meetings: meetings = newValue
      case .finder: finder = newValue
      case .captures: captures = newValue
      case .altTab: altTab = newValue
      case .dock: dock = newValue
      case .island: island = newValue
      case .remote: remote = newValue
      }
    }
  }

  /// Los módulos encendidos, en el orden de `Module.allCases`.
  public var enabled: [Module] { Module.allCases.filter { self[$0] } }
}

/// Dónde está la ventana de Sintecla: Inicio, General, Módulos o una página de un módulo.
public enum WindowPlace: Hashable, Sendable {
  case home, general, modules
  case page(ModulePage)

  public var module: Module? {
    if case .page(let page) = self { return page.module }
    return nil
  }

  /// Una página de un módulo apagado no se puede ver: vuelve a Inicio.
  public func resolved(with switches: ModuleSwitches) -> WindowPlace {
    if let module, !switches[module] { return .home }
    return self
  }
}

/// Los resúmenes de las tarjetas de Inicio.
public enum HomeSummary {
  public static func dictation(uses: Int, words: Int) -> String {
    guard uses > 0 else { return "Aún no has dictado hoy" }
    return "\(uses) \(uses == 1 ? "dictado" : "dictados") · \(words) \(words == 1 ? "palabra" : "palabras") hoy"
  }

  /// Actas listas de los últimos 7 días y reuniones pendientes (de cuando sean).
  public static func meetings(_ records: [MeetingRecord], now: Date = Date()) -> String {
    let weekAgo = now.addingTimeInterval(-7 * 86_400)
    let ready = records.filter { $0.status == .ready && $0.startedAt > weekAgo && $0.startedAt <= now }.count
    let pending = records.filter { $0.status == .pending }.count
    var text = ready == 0 ? "Sin actas esta semana" : "\(ready) \(ready == 1 ? "acta" : "actas") esta semana"
    if pending > 0 { text += " · \(pending) \(pending == 1 ? "pendiente" : "pendientes")" }
    return text
  }
}
