import AppKit
import SinteclaCore

/// Módulo Capturas (spec «Capturas» §2): de cada atajo a la captura, el portapapeles y la pastilla o la tarjeta.
@MainActor
final class CaptureController {
  static let imageSymbol = "camera.viewfinder"
  static let textSymbol = "text.viewfinder"
  static let codeSymbol = "qrcode.viewfinder"

  /// Aviso para la pastilla, con su símbolo.
  var onNotice: ((String, String) -> Void)?
  /// Falta el permiso de Grabación de pantalla: se abre la página Capturas.
  var onNeedsPermission: (() -> Void)?

  private let settings: AppSettings
  private let appleModel: AppleTextModel?
  /// La tarjeta de ⇧⌘1.
  private lazy var card = CaptureTextCardPanel(assistant: { [unowned self] in self.assistant() },
                                                preferred: { [unowned self] in self.settings.translationTarget })
  /// Una captura cada vez: mientras está la cruz de macOS, otro atajo no hace nada.
  private var busy = false

  init(settings: AppSettings, appleModel: AppleTextModel?) {
    self.settings = settings
    self.appleModel = appleModel
  }

  /// Lo llama el `EventTap` con cada pulsación que no usan los atajos de dictado ni Finder. `true`: Sintecla se la queda.
  func keyDown(keyCode: Int64, modifiers: Set<ComboModifier>) -> Bool {
    guard settings.moduleCaptures, let action = CaptureShortcut.action(keyCode: keyCode, modifiers: modifiers) else {
      return false
    }
    Task { await run(action) }
    return true
  }

  func run(_ action: CaptureAction) async {
    guard !busy else { return }
    guard ScreenCapture.hasPermission else {
      onNotice?(CaptureNotice.noPermission, "exclamationmark.triangle")
      onNeedsPermission?()
      return
    }
    busy = true
    defer { busy = false }
    guard let shot = await ScreenCapture.capture(action == .screen ? .screenUnderMouse : .interactive) else { return }
    switch action {
    case .screen, .area:
      ScreenCapture.copyImage(shot)
      onNotice?(CaptureNotice.copied, Self.imageSymbol)
    case .text, .textCard:
      let content = (try? await TextRecognizer.recognize(shot.image)) ?? .nothing
      guard let text = content.copiedText else {
        onNotice?(CaptureNotice.noText, Self.textSymbol)
        return
      }
      ScreenCapture.copyText(text)
      if case .codes(let codes) = content {
        onNotice?(CaptureNotice.codes(codes), Self.codeSymbol)
      } else {
        onNotice?(CaptureNotice.text(text), Self.textSymbol)
      }
      if action == .textCard { card.show(text) }
    }
  }

  /// Traductores: Apple y, de respaldo, Gemini. Modelos para preguntar: Gemini y, de respaldo, Apple.
  private func assistant() -> CaptureAssistant {
    let cloud = settings.cloudModel()
    let apple: TextModel? = appleModel == nil ? nil : AppleTextModel(temperature: 0.4)
    let translators: [Translating] = [AppleTranslator()] + [cloud.map { ModelTranslator(model: $0) as Translating }].compactMap { $0 }
    return CaptureAssistant(translators: translators, models: [cloud as TextModel?, apple].compactMap { $0 })
  }
}
