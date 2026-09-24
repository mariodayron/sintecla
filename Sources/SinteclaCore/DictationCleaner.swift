import Foundation

public struct CleanupResult: Equatable, Sendable {
  public enum Engine: String, Codable, Sendable {
    case gemini, apple, rules
  }

  public var text: String
  public var engine: Engine

  public init(text: String, engine: Engine) {
    self.text = text
    self.engine = engine
  }
}

/// Dictado crudo → texto listo para pegar.
/// Reglas → diccionario → IA local por trozos → filtro anti-invención → reglas otra vez → tono.
public struct DictationCleaner: Sendable {
  public let model: TextModel?
  public let dictionary: PersonalDictionary
  public let isKnownWord: @Sendable (String) -> Bool
  public var outputGuard = OutputGuard()
  public var rules = RulesCleaner()
  public var maxChunkChars = 1500

  public init(model: TextModel?, dictionary: PersonalDictionary, isKnownWord: @escaping @Sendable (String) -> Bool) {
    self.model = model
    self.dictionary = dictionary
    self.isKnownWord = isKnownWord
  }

  /// Tope de tokens de la respuesta: de sobra para limpiar (el filtro no deja pasar
  /// más de 1,3× la entrada) y corta enseguida si la IA se pone a responder.
  public static func maxTokens(for chunk: String) -> Int {
    chunk.count * 2 / 3 + 32
  }

  /// Antes de la IA: reglas, reemplazos y corrección aproximada del diccionario.
  public func preClean(_ raw: String) -> String {
    let pre = dictionary.applyRules(to: rules.clean(raw))
    return dictionary.fuzzyFix(pre, isKnownWord: isKnownWord)
  }

  /// Después de la IA: reemplazos, grafía de los términos y ajuste de tono.
  public func finish(_ text: String, tone: Tone) -> String {
    let text = dictionary.restoreTerms(dictionary.applyRules(to: text))
    return ToneFormatter.postProcess(text, tone: tone)
  }

  public func clean(_ raw: String, tone: Tone) async -> CleanupResult {
    let pre = preClean(raw)
    guard !pre.isEmpty else { return CleanupResult(text: "", engine: .rules) }

    let instructions = PromptLibrary.dictationInstructions(tone: tone)
    var pieces: [String] = []
    var aiEverywhere = model != nil
    for chunk in Chunker.split(pre, maxChars: maxChunkChars) {
      if let model, let output = try? await model.complete(instructions: instructions, prompt: PromptLibrary.wrap(chunk),
                                                           maxTokens: Self.maxTokens(for: chunk)) {
        let candidate = PromptLibrary.unwrap(output)
        if outputGuard.accepts(input: chunk, output: candidate, allowedNewWords: Set(dictionary.terms)) {
          pieces.append(candidate)
          continue
        }
      }
      aiEverywhere = false
      pieces.append(TextMetrics.finalize(chunk))
    }

    return CleanupResult(text: finish(pieces.joined(separator: " "), tone: tone), engine: aiEverywhere ? .apple : .rules)
  }
}
