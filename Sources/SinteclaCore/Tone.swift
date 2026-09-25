import Foundation

/// Tono de escritura según la app donde se dicta.
public enum Tone: String, Codable, CaseIterable, Sendable {
  case formal, informal, technical, prompt, neutral

  public var label: String {
    switch self {
    case .formal: "Formal"
    case .informal: "Informal"
    case .technical: "Técnico"
    case .prompt: "Prompt para IA"
    case .neutral: "Neutro"
    }
  }
}

/// Qué tono usa cada app (por bundle id) y, en Safari, cada web (por dominio). Editable en Ajustes → Tonos.
public struct ToneRules: Codable, Equatable, Sendable {
  public var byBundleID: [String: Tone]
  /// Dominio sin `www.` → tono. Solo cuenta en Safari (`SiteRules.browsers`).
  public var bySite: [String: Tone]
  /// 2 desde la 0.8.0 (tono Prompt para IA). Los tones.json de antes no la tienen.
  public var version: Int

  public static let currentVersion = 2
  /// Apps y webs de IA que en la 0.8.0 pasan de Técnico (su valor por defecto hasta entonces) a Prompt.
  static let aiApps: Set<String> = ["com.anthropic.claudefordesktop", "com.openai.chat", "com.openai.codex"]
  static let aiSites: Set<String> = ["claude.ai", "chatgpt.com", "gemini.google.com"]

  public init(byBundleID: [String: Tone], bySite: [String: Tone] = [:], version: Int = Self.currentVersion) {
    self.byBundleID = byBundleID
    self.bySite = bySite
    self.version = version
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    byBundleID = try container.decode([String: Tone].self, forKey: .byBundleID)
    // Los tones.json de antes de la 0.5.0 no tienen webs: reciben la lista inicial.
    bySite = try container.decodeIfPresent([String: Tone].self, forKey: .bySite) ?? Self.defaults.bySite
    version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
    // Una sola vez: las apps y webs de IA que siguen en Técnico pasan a Prompt; otro tono elegido se respeta.
    if version < 2 {
      for id in Self.aiApps where byBundleID[id] == .technical { byBundleID[id] = .prompt }
      for site in Self.aiSites where bySite[site] == .technical { bySite[site] = .prompt }
      version = Self.currentVersion
    }
  }

  /// En Safari, el tono de la web si está en la lista; si no, el de la app.
  public func tone(for bundleID: String?, host: String? = nil) -> Tone {
    guard let bundleID else { return .neutral }
    if SiteRules.browsers.contains(bundleID), let host, let site = SiteRules.match(host, in: bySite.keys),
       let tone = bySite[site] {
      return tone
    }
    return byBundleID[bundleID] ?? .neutral
  }

  public static let defaults = ToneRules(byBundleID: [
    // Formal
    "com.apple.mail": .formal,
    "com.microsoft.Outlook": .formal,
    "com.microsoft.Word": .formal,
    "com.apple.iWork.Pages": .formal,
    "com.readdle.SparkDesktop": .formal,
    // Informal
    "net.whatsapp.WhatsApp": .informal,
    "ru.keepcoder.Telegram": .informal,
    "com.apple.MobileSMS": .informal,
    "com.tinyspeck.slackmacgap": .informal,
    "com.hnc.Discord": .informal,
    // Técnico
    "com.microsoft.VSCode": .technical,
    "com.todesktop.230313mzl4w4u92": .technical,  // Cursor
    "com.apple.Terminal": .technical,
    "com.googlecode.iterm2": .technical,
    "dev.warp.Warp-Stable": .technical,
    // Prompt para IA
    "com.anthropic.claudefordesktop": .prompt,
    "com.openai.chat": .prompt,
    "com.openai.codex": .prompt,
  ], bySite: [
    // Formal
    "mail.google.com": .formal,
    "outlook.live.com": .formal,
    "outlook.office.com": .formal,
    "outlook.office365.com": .formal,
    "docs.google.com": .formal,
    // Informal
    "web.whatsapp.com": .informal,
    "web.telegram.org": .informal,
    "slack.com": .informal,
    "discord.com": .informal,
    "messenger.com": .informal,
    // Técnico
    "github.com": .technical,
    // Prompt para IA
    "chatgpt.com": .prompt,
    "claude.ai": .prompt,
    "gemini.google.com": .prompt,
  ])
}

public enum ToneFormatter {
  /// Línea extra para las instrucciones de la IA.
  public static func instruction(for tone: Tone) -> String {
    switch tone {
    case .formal: "Tono formal: frases completas y puntuación cuidada; si hay saludo o despedida, ponlos en su propia línea."
    case .informal: "Tono informal de chat: puntuación ligera y natural."
    case .technical: "Contexto técnico: conserva literalmente términos técnicos, nombres de código, rutas y palabras en inglés."
    case .prompt: "Es un mensaje para una IA: pon primero lo que se pide y conserva literalmente términos técnicos, código, rutas y palabras en inglés."
    case .neutral: ""
    }
  }

  /// Línea de tono para Gemini, más detallada que la del modelo local (spec «Ordenar el dictado» §3).
  public static func cloudInstruction(for tone: Tone) -> String {
    switch tone {
    case .formal: "formal: frases completas y cuidadas; si hay saludo o despedida, cada uno en su propia línea; mantén el tú o el usted que use"
    case .informal: "informal de chat: frases cortas y naturales, puntuación ligera"
    case .technical: "técnico: conserva literalmente términos técnicos, nombres de código, comandos, rutas y palabras en inglés; si describe pasos, ponlos en lista numerada"
    case .prompt: "prompt para una IA: empieza por lo que se pide y después el contexto; si hay 2 o más requisitos, condiciones o pasos, ponlos en lista con «- » bajo una etiqueta corta («Requisitos:», «Pasos:» o «Contexto:»); conserva literalmente términos técnicos, código, rutas y palabras en inglés; no añadas requisitos, roles, formatos ni peticiones que no haya dicho"
    case .neutral: "neutro: claro y correcto"
    }
  }

  /// Etiquetas que el tono Prompt pone a sus listas: el filtro no las cuenta como palabras nuevas.
  public static func allowedLabels(for tone: Tone) -> [String] {
    tone == .prompt ? ["Requisitos", "Contexto", "Pasos", "Objetivo"] : []
  }

  /// Ajuste final tras la IA. Informal: sin punto final si es un único enunciado. Formal: saludo y despedida en su
  /// propia línea (el modelo local no lo hace aunque se le pida).
  public static func postProcess(_ text: String, tone: Tone) -> String {
    switch tone {
    case .informal: dropFinalPeriod(text)
    case .formal: separateGreetingAndFarewell(text)
    case .technical, .prompt, .neutral: text
    }
  }

  static func dropFinalPeriod(_ text: String) -> String {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard t.hasSuffix("."), !t.hasSuffix("..."), !t.contains("\n") else { return t }
    let body = t.dropLast()
    if body.contains(". ") || body.contains("? ") || body.contains("! ") { return t }
    return String(body)
  }

  /// Saludo al principio: la fórmula, el nombre (palabras con mayúscula o unas pocas en minúscula) y su signo.
  static let greeting = try! NSRegularExpression(pattern:
    #"^(?i:hola|buenos días|buenas tardes|buenas noches|buenas|estimad[oa]s?|querid[oa]s?|hi|hello|dear|good morning|good afternoon|good evening)"#
    + #"(?:,?\s+(?:\p{Lu}[\p{L}'’-]*|(?i:a|de|del|la|señor|señora|sr\.|sra\.|don|doña|todos|todas|equipo|clientes|compañeros|compañeras|colegas|amigos)\b))*"#
    + #"\s*[,:.!]"#)

  /// Despedida al final: la última frase, si empieza por una fórmula de despedida (puede llevar la firma).
  static let farewell = try! NSRegularExpression(pattern:
    #"(?<=[.!?…])\s+((?i:un (?:cordial |fuerte |afectuoso )?saludo|saludos(?: cordiales)?|un abrazo|abrazos|atentamente|cordialmente|"#
    + #"un beso|besos|muchas gracias|mil gracias|gracias|hasta pronto|best regards|kind regards|regards|many thanks|thanks|"#
    + #"thank you|cheers|sincerely|best)\b(?:[,\s]+[^.!?\n]{0,40})?[.!]?)$"#)

  static func separateGreetingAndFarewell(_ text: String) -> String {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    // Si ya viene en varias líneas, se respeta.
    guard !t.contains("\n") else { return text }
    var head: String?
    var body = t
    if let match = greeting.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)), let range = Range(match.range, in: t) {
      let rest = t[range.upperBound...].trimmingCharacters(in: .whitespaces)
      if !rest.isEmpty {
        head = String(t[range])
        body = rest
      }
    }
    var tail: String?
    if let match = farewell.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)),
       let whole = Range(match.range, in: body), let phrase = Range(match.range(at: 1), in: body) {
      tail = String(body[phrase])
      body = String(body[..<whole.lowerBound])
    }
    guard head != nil || tail != nil else { return text }
    return [head, capitalizingFirstLetter(body), tail].compactMap { $0 }.joined(separator: "\n\n")
  }

  static func capitalizingFirstLetter(_ text: String) -> String {
    guard let i = text.firstIndex(where: \.isLetter) else { return text }
    return text.replacingCharacters(in: i...i, with: String(text[i]).uppercased())
  }
}
