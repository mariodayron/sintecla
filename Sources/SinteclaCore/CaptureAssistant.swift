import Foundation
import NaturalLanguage

/// Traducir y preguntar sobre el texto de una captura: la tarjeta de ⇧⌘1 (spec «Capturas» §2.5).
public struct CaptureAssistant: Sendable {
  /// En orden: Apple y, de respaldo, Gemini.
  public let translators: [Translating]
  /// En orden: Gemini y, de respaldo, Apple.
  public let models: [TextModel]

  static let askInstructions = """
    Responde en español, breve y claro, a la pregunta de la persona sobre el texto que ha copiado de su pantalla. \
    Básate en ese texto; si no basta, dilo. Sin saludos ni despedidas.
    """
  static let maxAnswerTokens = 600

  public init(translators: [Translating], models: [TextModel]) {
    self.translators = translators
    self.models = models
  }

  /// Un texto en español va al idioma de «Traducir a» (o al inglés, si también es el español); cualquier otro, al español.
  public static func languages(for text: String, preferred: TranslationLanguage) -> (source: TranslationLanguage, target: TranslationLanguage) {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    let source = recognizer.dominantLanguage.flatMap { TranslationLanguage(rawValue: String($0.rawValue.prefix(2))) } ?? .en
    return source == .es ? (.es, TranslationLanguage.resolve(target: preferred, source: .es)) : (source, .es)
  }

  /// nil si ningún traductor lo consigue.
  public func translate(_ text: String, preferred: TranslationLanguage) async -> String? {
    let (source, target) = Self.languages(for: text, preferred: preferred)
    for translator in translators {
      guard let output = try? await translator.translate(text, from: source, to: target) else { continue }
      let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { return trimmed }
    }
    return nil
  }

  /// nil si ningún modelo responde.
  public func ask(_ question: String, about text: String) async -> String? {
    let prompt = "Texto:\n«\(text)»\n\nPregunta: \(question)"
    for model in models {
      guard let output = try? await model.complete(instructions: Self.askInstructions, prompt: prompt,
                                                   maxTokens: Self.maxAnswerTokens) else { continue }
      let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { return trimmed }
    }
    return nil
  }
}
