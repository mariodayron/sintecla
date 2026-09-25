import Foundation

/// Dictado crudo → texto ordenado, con Gemini si hay modelo en la nube (spec «Ordenar el dictado» §2).
/// Limpieza previa → Gemini con todo el texto → filtro → ajustes finales. Si no toca Gemini, falla o su
/// texto no pasa el filtro, lo ordena `DictationCleaner` en el Mac.
public struct DictationRewriter: Sendable {
  public struct Result: Equatable, Sendable {
    public var text: String
    public var engine: CleanupResult.Engine
    /// El error de Gemini, si lo hubo: entonces el texto es el del respaldo local.
    public var cloudError: CloudError?

    public init(text: String, engine: CleanupResult.Engine, cloudError: CloudError? = nil) {
      self.text = text
      self.engine = engine
      self.cloudError = cloudError
    }
  }

  /// Con menos palabras (tras la limpieza previa) no hay nada que ordenar: se queda en el Mac.
  public static let minimumWords = 6
  /// Segundos de espera a Gemini, sin reintentos.
  public static let timeout: TimeInterval = 6
  /// El tono Prompt reescribe más (imperativo, etiquetas y listas): admite hasta la mitad de palabras nuevas.
  public static let promptNovelRatio = 0.5

  /// Gemini (nil: sin clave o con el interruptor apagado).
  public let cloud: TextModel?
  /// El respaldo en el Mac.
  public let local: DictationCleaner
  public var outputGuard = OutputGuard()

  public init(cloud: TextModel?, local: DictationCleaner) {
    self.cloud = cloud
    self.local = local
  }

  /// `appName` y `site`: dónde se dicta; `style`: «Mi estilo».
  public func rewrite(_ raw: String, tone: Tone, appName: String? = nil, site: String? = nil, style: String = "") async -> Result {
    let pre = local.preClean(raw)
    guard let cloud, TextMetrics.wordCount(pre) >= Self.minimumWords else { return await fallback(raw, tone: tone) }
    let terms = local.dictionary.terms
    let instructions = PromptLibrary.rewriteInstructions(tone: tone, context: PromptLibrary.writingPlace(appName: appName, site: site),
                                                         style: style, terms: terms)
    do {
      let reply = PromptLibrary.unwrap(try await cloud.complete(instructions: instructions, prompt: PromptLibrary.wrap(pre)))
      let output = Self.removingMadeUpGreetings(reply, dictated: pre)
      var check = outputGuard
      if tone == .prompt { check.maxNovelRatio = max(check.maxNovelRatio, Self.promptNovelRatio) }
      guard check.accepts(input: pre, output: output, allowedNewWords: Set(terms + ToneFormatter.allowedLabels(for: tone))) else {
        return await fallback(raw, tone: tone)
      }
      return Result(text: local.finish(output, tone: tone), engine: .gemini)
    } catch {
      return await fallback(raw, tone: tone, error: error as? CloudError ?? .network(error.localizedDescription))
    }
  }

  /// Quita el saludo o la despedida que Gemini se inventa (lo saca de «Mi estilo» aunque se le pida que no): la primera
  /// o la última frase, si solo tiene palabras de saludo (`OutputGuard.greetingWords`) que no están en lo dictado.
  static func removingMadeUpGreetings(_ output: String, dictated: String) -> String {
    let said = Set(TextMetrics.contentWords(dictated))
    func madeUp(_ sentence: Substring) -> Bool {
      let words = TextMetrics.contentWords(String(sentence))
      return !words.isEmpty && words.allSatisfy { OutputGuard.greetingWords.contains($0) && !said.contains($0) }
    }
    let ends: Set<Character> = [".", "!", ":", "\n"]
    var text = output.trimmingCharacters(in: .whitespacesAndNewlines)
    if let end = text.firstIndex(where: ends.contains), madeUp(text[..<end]) {
      text = String(text[text.index(after: end)...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    let body = text.last.map { ".!".contains($0) } == true ? text.dropLast() : Substring(text)
    if let start = body.lastIndex(where: ends.contains), madeUp(body[body.index(after: start)...]) {
      text = String(body[...start]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return ToneFormatter.capitalizingFirstLetter(text)
  }

  private func fallback(_ raw: String, tone: Tone, error: CloudError? = nil) async -> Result {
    let result = await local.clean(raw, tone: tone)
    return Result(text: result.text, engine: result.engine, cloudError: error)
  }
}
