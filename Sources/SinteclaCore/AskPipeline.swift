import Foundation
import NaturalLanguage

/// Texto seleccionado en la app activa cuando empieza Ask Anything.
public struct Selection: Equatable, Sendable {
  public var text: String
  /// ¿Se puede escribir encima (cuadro de texto) o es solo lectura (una web)?
  public var editable: Bool

  public init(text: String, editable: Bool) {
    self.text = text
    self.editable = editable
  }
}

/// Qué hacer con el resultado de Ask Anything.
public enum AskOutcome: Equatable, Sendable {
  /// Pegar encima de la selección.
  case replace(String, engine: String)
  /// Mostrar en la tarjeta. `local`: respondió el modelo de Apple (sin Gemini).
  case answer(String, local: Bool, engine: String)
  case open(URL)
  /// Mensaje de error para la tarjeta; la selección no se toca.
  case failure(String)
  /// No se entendió nada.
  case silence
}

/// Acepta o rechaza la edición que propone la IA (su filtro es distinto al del dictado:
/// una edición puede traer palabras nuevas legítimamente).
public struct EditGuard: Sendable {
  public var minLengthRatio = 0.2
  /// Un resumen de un texto largo puede quedarse muy por debajo de 0,2×: basta con 20 caracteres.
  public var minLengthChars = 20
  public var maxLengthRatio = 3.0
  /// Margen para selecciones muy cortas ("alárgalo" sobre tres palabras).
  public var extraCharsAllowance = 200

  static let placeholder = try! NSRegularExpression(pattern: #"\\?\[[^\]\n]{1,40}\]"#)
  static let intro = try! NSRegularExpression(
    pattern: #"^(aquí tienes|aqui tienes|claro|por supuesto|here is|here's|sure)[^\n]*:\s*\n"#, options: [.caseInsensitive])

  public init() {}

  /// Devuelve la edición limpia (sin ```, comillas, etiquetas ni "Aquí tienes…:") o nil si no vale:
  /// vacía, igual que la selección, con huecos tipo "[Tu nombre]", de longitud fuera de 0,2×–3×
  /// (el mínimo nunca pasa de 20 caracteres) o, si `sameLanguage`, en otro idioma.
  public func accept(_ output: String, selection: String, sameLanguage: Bool = true) -> String? {
    let original = selection.trimmingCharacters(in: .whitespacesAndNewlines)
    var s = output.trimmingCharacters(in: .whitespacesAndNewlines)
    for tag in ["<texto>", "</texto>", "<orden>", "</orden>"] { s = s.replacingOccurrences(of: tag, with: "") }
    s = Self.intro.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
    if !original.contains("```") { s = Self.stripFences(s) }
    s = Self.stripQuotes(s, unless: original)
    s = s.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !s.isEmpty, s != original else { return nil }
    let inCount = Double(original.count), outCount = Double(s.count)
    guard outCount >= min(inCount * minLengthRatio, Double(minLengthChars)),
          outCount <= inCount * maxLengthRatio + Double(extraCharsAllowance) else { return nil }
    if Self.hasPlaceholder(s) && !Self.hasPlaceholder(original) { return nil }
    if sameLanguage, Self.changesLanguage(from: original, to: s) { return nil }
    return s
  }

  /// Solo con detección segura (≥ 0,8) en los dos textos: el código, por ejemplo, no la da.
  static func changesLanguage(from original: String, to edited: String) -> Bool {
    func language(_ text: String) -> NLLanguage? {
      let recognizer = NLLanguageRecognizer()
      recognizer.processString(text)
      guard let (language, confidence) = recognizer.languageHypotheses(withMaximum: 1).first, confidence >= 0.8 else { return nil }
      return language
    }
    guard let before = language(original), let after = language(edited) else { return false }
    return before != after
  }

  static func hasPlaceholder(_ text: String) -> Bool {
    placeholder.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
  }

  static func stripFences(_ text: String) -> String {
    var lines = text.components(separatedBy: "\n")
    guard lines.count >= 2, lines.first!.hasPrefix("```"), lines.last!.hasPrefix("```") else { return text }
    lines.removeFirst()
    lines.removeLast()
    return lines.joined(separator: "\n")
  }

  static func stripQuotes(_ text: String, unless original: String) -> String {
    for (open, close) in [("\"", "\""), ("«", "»"), ("“", "”")] {
      if text.count > 2, text.hasPrefix(open), text.hasSuffix(close), !original.hasPrefix(open) {
        return String(text.dropFirst(open.count).dropLast(close.count))
      }
    }
    return text
  }
}

/// Enrutado de Ask Anything:
///
/// | Selección  | Intención   | Motor                                  | Salida              |
/// |------------|-------------|----------------------------------------|---------------------|
/// | cualquiera | "tradúcelo" | Traductor de Apple                     | reemplaza o tarjeta |
/// | editable   | edición     | Apple (Gemini si > 2.500 car. o falla) | reemplaza selección |
/// | editable   | pregunta    | Gemini (Apple sin clave o sin red)     | tarjeta             |
/// | no editable| cualquiera  | Gemini (Apple sin clave o sin red)     | tarjeta             |
/// | ninguna    | acción web  | Gemini JSON (reglas si falla)          | abre la URL         |
/// | ninguna    | otra        | Gemini (Apple sin clave o sin red)     | tarjeta             |
public struct AskPipeline: Sendable {
  public static let appleEditLimit = 2500
  /// Selección máxima que se manda: el modelo de Apple solo tiene 4.096 tokens.
  public static let appleSelectionLimit = 6000
  public static let cloudSelectionLimit = 60000

  /// Modelo de Apple para editar (greedy).
  public let apple: TextModel?
  /// Modelo de Apple para responder sin Gemini (con temperatura); si falta, se usa `apple`.
  public let localAnswers: TextModel?
  /// Gemini; nil si no hay clave.
  public let cloud: (any TextModel & StructuredModel)?
  /// Traductor de Apple para las órdenes "tradúcelo al …".
  public let translator: Translating?
  /// "Mi estilo" (Ajustes → IA): se añade a las instrucciones de edición.
  public var style: String
  public var editGuard = EditGuard()

  public init(apple: TextModel?, localAnswers: TextModel? = nil, cloud: (any TextModel & StructuredModel)?,
              translator: Translating? = nil, style: String = "") {
    self.apple = apple
    self.localAnswers = localAnswers
    self.cloud = cloud
    self.translator = translator
    self.style = style
  }

  public func run(command raw: String, selection: Selection?) async -> AskOutcome {
    let command = RulesCleaner().clean(raw)
    guard !command.isEmpty else { return .silence }
    switch (IntentClassifier.classify(command, hasSelection: selection != nil), selection) {
    case (.webAction, nil):
      return .open(await webAction(command).url)
    case (.edit, let selection?):
      if let target = TranslationCommand.target(of: command), let translated = await translate(selection.text, to: target) {
        return selection.editable ? .replace(translated, engine: "apple") : .answer(translated, local: true, engine: "apple")
      }
      if selection.editable { return await edit(command, selection) }
      return await answer(command, selection: selection)
    default:
      return await answer(command, selection: selection)
    }
  }

  func translate(_ text: String, to target: TranslationLanguage) async -> String? {
    guard let translator, let source = TranslationCommand.language(of: text), source != target,
          let output = try? await translator.translate(text, from: source, to: target) else { return nil }
    let result = output.trimmingCharacters(in: .whitespacesAndNewlines)
    return TranslationGuard().accepts(input: text, output: result, target: target) ? result : nil
  }

  func edit(_ command: String, _ selection: Selection) async -> AskOutcome {
    let instructions = PromptLibrary.editInstructions(style: style)
    let prompt = PromptLibrary.editPrompt(text: selection.text, command: command)
    let sameLanguage = !TranslationCommand.mentionsLanguage(command)
    if let apple, selection.text.count <= Self.appleEditLimit,
       let output = try? await apple.complete(instructions: instructions, prompt: prompt,
                                              maxTokens: selection.text.count + 200),
       let edited = editGuard.accept(output, selection: selection.text, sameLanguage: sameLanguage) {
      return .replace(edited, engine: "apple")
    }
    guard let cloud else { return .failure("La IA local no pudo hacer esa edición. Con la clave de Gemini (Ajustes → IA) se reintenta en la nube.") }
    do {
      let output = try await cloud.complete(instructions: instructions, prompt: prompt)
      guard let edited = editGuard.accept(output, selection: selection.text, sameLanguage: sameLanguage) else {
        return .failure("La edición no parecía correcta: no he tocado tu texto.")
      }
      return .replace(edited, engine: "gemini")
    } catch {
      return .failure((error as? CloudError)?.userMessage ?? "No se pudo editar el texto")
    }
  }

  func answer(_ command: String, selection: Selection?) async -> AskOutcome {
    let instructions = PromptLibrary.answerInstructions
    var cloudError: CloudError?
    if let cloud {
      let prompt = PromptLibrary.answerPrompt(question: command, selection: selection?.text, limit: Self.cloudSelectionLimit)
      do {
        return .answer(try await cloud.complete(instructions: instructions, prompt: prompt), local: false, engine: "gemini")
      } catch {
        cloudError = error as? CloudError
      }
    }
    if let model = localAnswers ?? apple {
      let prompt = PromptLibrary.answerPrompt(question: command, selection: selection?.text, limit: Self.appleSelectionLimit)
      if let output = try? await model.complete(instructions: instructions, prompt: prompt, maxTokens: 500) {
        return .answer(output.trimmingCharacters(in: .whitespacesAndNewlines), local: true, engine: "apple")
      }
    }
    return .failure(cloudError?.userMessage ?? "No hay ninguna IA disponible para responder")
  }

  func webAction(_ command: String) async -> WebAction {
    if let cloud,
       let data = try? await cloud.completeJSON(instructions: PromptLibrary.webActionInstructions, prompt: command,
                                                schemaName: "accion_web", schema: WebAction.jsonSchema),
       let action = WebAction.decode(data) {
      return action
    }
    return WebActionParser.parse(command)
  }
}
