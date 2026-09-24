import Foundation
import NaturalLanguage
import Translation

/// Idiomas de destino. Todos los traduce Apple en el Mac (comprobado: es → todos "installed").
public enum TranslationLanguage: String, CaseIterable, Codable, Sendable {
  case en, es, fr, de, it, pt, ja, zh, ko

  /// Nombre en su propio idioma, para el menú.
  public var name: String {
    switch self {
    case .en: "English"
    case .es: "Español"
    case .fr: "Français"
    case .de: "Deutsch"
    case .it: "Italiano"
    case .pt: "Português"
    case .ja: "日本語"
    case .zh: "中文"
    case .ko: "한국어"
    }
  }

  /// Nombre en español, para las instrucciones de la IA.
  public var spanishName: String {
    switch self {
    case .en: "inglés"
    case .es: "español"
    case .fr: "francés"
    case .de: "alemán"
    case .it: "italiano"
    case .pt: "portugués"
    case .ja: "japonés"
    case .zh: "chino"
    case .ko: "coreano"
    }
  }

  /// Idioma de un identificador de dictado: "es_ES" → .es, "en_US" → .en.
  public static func of(locale identifier: String) -> TranslationLanguage {
    TranslationLanguage(rawValue: String(identifier.prefix(2))) ?? .es
  }

  /// Si el destino es el mismo idioma en el que se dicta, se traduce al otro (español ↔ inglés).
  public static func resolve(target: TranslationLanguage, source: TranslationLanguage) -> TranslationLanguage {
    guard target == source else { return target }
    return source == .en ? .es : .en
  }

  var nlLanguages: Set<NLLanguage> {
    self == .zh ? [.simplifiedChinese, .traditionalChinese] : [NLLanguage(rawValue: rawValue)]
  }
}

public protocol Translating: Sendable {
  func translate(_ text: String, from source: TranslationLanguage, to target: TranslationLanguage) async throws -> String
}

/// Traducción de Apple (framework Translation): gratis, sin internet y nunca contesta al texto.
public struct AppleTranslator: Translating {
  public init() {}

  public func translate(_ text: String, from source: TranslationLanguage, to target: TranslationLanguage) async throws -> String {
    let from = Locale.Language(identifier: source.rawValue)
    let to = Locale.Language(identifier: target.rawValue)
    let session: TranslationSession
    if #available(macOS 26.4, *) {
      // "highFidelity" respeta mejor los nombres propios ("Supabase"; "lowLatency" escribió "Subase").
      session = TranslationSession(installedSource: from, target: to, preferredStrategy: .highFidelity)
    } else {
      session = TranslationSession(installedSource: from, target: to)
    }
    return try await session.translate(text).targetText
  }
}

/// Traducción con un modelo de lenguaje (Gemini como respaldo).
public struct ModelTranslator: Translating {
  public let model: TextModel

  public init(model: TextModel) {
    self.model = model
  }

  public func translate(_ text: String, from source: TranslationLanguage, to target: TranslationLanguage) async throws -> String {
    let output = try await model.complete(instructions: PromptLibrary.translationInstructions(to: target),
                                          prompt: PromptLibrary.wrap(text))
    return PromptLibrary.unwrap(output)
  }
}

/// Acepta una traducción si está en el idioma destino, tiene una longitud razonable
/// y, si el original era una pregunta, sigue siéndolo.
public struct TranslationGuard: Sendable {
  public var minLengthRatio = 0.5
  public var maxLengthRatio = 2.0
  /// Margen para textos muy cortos ("Vale." → "Okay.").
  public var extraCharsAllowance = 8

  public init() {}

  public func accepts(input: String, output: String, target: TranslationLanguage) -> Bool {
    let out = output.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !out.isEmpty else { return false }
    let inCount = Double(input.count), outCount = Double(out.count)
    guard outCount >= inCount * minLengthRatio - Double(extraCharsAllowance),
          outCount <= inCount * maxLengthRatio + Double(extraCharsAllowance) else { return false }
    if input.contains("?") && !(out.contains("?") || out.contains("？")) { return false }
    return isInLanguage(out, target)
  }

  /// Con menos de 3 palabras la detección no es fiable ("Hello Ana" sale turco): no se comprueba.
  func isInLanguage(_ text: String, _ target: TranslationLanguage) -> Bool {
    guard TextMetrics.wordCount(text) >= 3 else { return true }
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    if let dominant = recognizer.dominantLanguage, target.nlLanguages.contains(dominant) { return true }
    let hypotheses = recognizer.languageHypotheses(withMaximum: 3)
    return target.nlLanguages.contains { (hypotheses[$0] ?? 0) >= 0.3 }
  }
}

public struct TranslationResult: Equatable, Sendable {
  public enum Engine: String, Sendable {
    /// `untranslated`: no se pudo traducir y se devuelve el texto limpio sin traducir.
    case apple, gemini, untranslated
  }

  public var text: String
  public var engine: Engine

  public init(text: String, engine: Engine) {
    self.text = text
    self.engine = engine
  }
}

/// Dictado → limpieza (igual que el dictado) → traducción de Apple → Gemini si falla → tono.
public struct TranslationPipeline: Sendable {
  public let cleaner: DictationCleaner
  public let primary: Translating?
  public let fallback: Translating?
  public var translationGuard = TranslationGuard()

  public init(cleaner: DictationCleaner, primary: Translating?, fallback: Translating?) {
    self.cleaner = cleaner
    self.primary = primary
    self.fallback = fallback
  }

  public func run(_ raw: String, source: TranslationLanguage, target: TranslationLanguage, tone: Tone) async -> TranslationResult {
    let cleaned = await cleaner.clean(raw, tone: tone).text
    guard !cleaned.isEmpty else { return TranslationResult(text: "", engine: .untranslated) }
    let to = TranslationLanguage.resolve(target: target, source: source)
    let engines: [(TranslationResult.Engine, Translating?)] = [(.apple, primary), (.gemini, fallback)]
    for (engine, translator) in engines {
      guard let translator, let output = try? await translator.translate(cleaned, from: source, to: to) else { continue }
      let text = cleaner.dictionary.restoreTerms(output.trimmingCharacters(in: .whitespacesAndNewlines))
      if translationGuard.accepts(input: cleaned, output: text, target: to) {
        return TranslationResult(text: ToneFormatter.postProcess(text, tone: tone), engine: engine)
      }
    }
    return TranslationResult(text: cleaned, engine: .untranslated)
  }
}
