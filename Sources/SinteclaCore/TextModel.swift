import Foundation
import FoundationModels

/// Un modelo de lenguaje que completa texto. Permite tests con modelos falsos.
public protocol TextModel: Sendable {
  /// `maxTokens` corta respuestas desbocadas (p. ej. un poema cuando se dictó "escribe un poema").
  func complete(instructions: String, prompt: String, maxTokens: Int?) async throws -> String
}

public extension TextModel {
  func complete(instructions: String, prompt: String) async throws -> String {
    try await complete(instructions: instructions, prompt: prompt, maxTokens: nil)
  }
}

/// Modelo local de Apple Intelligence: gratis, sin internet, 4.096 tokens de contexto.
public final class AppleTextModel: TextModel, @unchecked Sendable {
  /// nil = muestreo *greedy* (limpiar y editar: siempre igual). Con respuestas largas el greedy
  /// entra en bucle repitiendo frases; para responder se usa temperatura 0,4 (probado).
  public let temperature: Double?
  private let lock = NSLock()
  private var warm: (instructions: String, session: LanguageModelSession)?

  public init(temperature: Double? = nil) {
    self.temperature = temperature
  }

  public static var isAvailable: Bool {
    if case .available = SystemLanguageModel.default.availability { return true }
    return false
  }

  /// Carga el modelo antes de que haga falta (se llama al empezar a grabar).
  public func prewarm(instructions: String) {
    let session = LanguageModelSession(instructions: instructions)
    session.prewarm()
    lock.withLock { warm = (instructions, session) }
  }

  public func complete(instructions: String, prompt: String, maxTokens: Int?) async throws -> String {
    let session: LanguageModelSession = lock.withLock {
      if let w = warm, w.instructions == instructions {
        warm = nil
        return w.session
      }
      return LanguageModelSession(instructions: instructions)
    }
    let options = temperature.map { GenerationOptions(temperature: $0, maximumResponseTokens: maxTokens) }
      ?? GenerationOptions(sampling: .greedy, maximumResponseTokens: maxTokens)
    let response = try await session.respond(to: prompt, options: options)
    return response.content
  }
}
