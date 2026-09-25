import AppKit
import Observation
import SinteclaCore
import SwiftUI

/// Estado de la tarjeta de ⇧⌘1.
@MainActor @Observable
final class CaptureCardModel {
  var text = ""
  var translation: String?
  var answer: String?
  var question = ""
  /// El campo de la pregunta está a la vista.
  var asking = false
  var working = false
  var problem: String?
  /// Lo último que se copió («texto», «traducción» o «respuesta»), para el «Copiado».
  var copied: String?
}

/// La tarjeta de ⇧⌘1 (spec «Capturas» §2.5): el texto (se puede editar), su traducción y la respuesta a una pregunta.
struct CaptureTextCardView: View {
  @Bindable var model: CaptureCardModel
  var onCopy: (String, String) -> Void
  var onTranslate: () -> Void
  var onAsk: () -> Void
  var onClose: () -> Void
  @FocusState private var questionFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        Image(systemName: CaptureController.textSymbol)
          .font(.system(size: 14, weight: .semibold))
          .frame(width: 30, height: 30)
          .background(.quaternary, in: .circle)
        Text("Texto de la pantalla").font(.system(.headline, design: .rounded))
        Spacer(minLength: 8)
        Button(action: onClose) {
          Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
            .frame(width: 26, height: 26).background(.quaternary, in: .circle)
        }
        .buttonStyle(.plain)
        .help("Cerrar (Esc)")
      }
      TextEditor(text: $model.text)
        .font(.system(size: 14))
        .scrollContentBackground(.hidden)
        .padding(8)
        .frame(height: 120)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))
      if let translation = model.translation { result("Traducción", translation, key: "traducción") }
      if model.asking {
        TextField("Pregunta sobre el texto (Intro para enviar)", text: $model.question)
          .textFieldStyle(.roundedBorder)
          .focused($questionFocused)
          .onSubmit(onAsk)
          .onAppear { questionFocused = true }
      }
      if let answer = model.answer { result("Respuesta", answer, key: "respuesta") }
      if let problem = model.problem { Text(problem).font(.callout).foregroundStyle(.secondary) }
      HStack(spacing: 8) {
        if model.working { ProgressView().controlSize(.small) }
        Spacer()
        CardButton(title: model.copied == "texto" ? "Copiado" : "Copiar",
                   symbol: model.copied == "texto" ? "checkmark" : "doc.on.doc", prominent: false) {
          onCopy(model.text, "texto")
        }
        CardButton(title: "Traducir", symbol: "translate", prominent: false, action: onTranslate)
        CardButton(title: "Preguntar", symbol: "sparkles", prominent: true, action: onAsk)
      }
    }
    .padding(16)
    .glassEffect(.regular, in: .rect(cornerRadius: 26))
    .padding(6)
    .frame(width: 492)
  }

  private func result(_ title: String, _ text: String, key: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(title).font(.system(.caption, design: .rounded).weight(.semibold)).foregroundStyle(.secondary)
        Spacer()
        Button(model.copied == key ? "Copiado" : "Copiar") { onCopy(text, key) }
          .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
      }
      ScrollView {
        Text(AskCardView.markdown(text)).font(.system(size: 14)).textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxHeight: 160)
    }
  }
}

/// Panel que acepta el teclado sin activar Sintecla (para editar el texto y escribir la pregunta). Esc lo cierra.
final class KeyablePanel: NSPanel {
  override var canBecomeKey: Bool { true }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .keyDown, event.keyCode == 53 {  // 53 = Esc
      orderOut(nil)
      return
    }
    super.sendEvent(event)
  }
}

@MainActor
final class CaptureTextCardPanel {
  let model = CaptureCardModel()
  private let panel: KeyablePanel
  private var hosting: FirstMouseHostingView<CaptureTextCardView>!
  private let assistant: () -> CaptureAssistant
  private let preferred: () -> TranslationLanguage

  init(assistant: @escaping () -> CaptureAssistant, preferred: @escaping () -> TranslationLanguage) {
    self.assistant = assistant
    self.preferred = preferred
    panel = KeyablePanel(contentRect: NSRect(x: 0, y: 0, width: 492, height: 300),
                         styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
    panel.isFloatingPanel = true
    panel.level = .statusBar
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false  // el cristal ya lleva su sombra
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    hosting = FirstMouseHostingView(rootView: CaptureTextCardView(
      model: model,
      onCopy: { [weak self] text, key in self?.copy(text, key: key) },
      onTranslate: { [weak self] in self?.translate() },
      onAsk: { [weak self] in self?.ask() },
      onClose: { [weak self] in self?.close() }))
    panel.contentView = hosting
  }

  func show(_ text: String) {
    model.text = text
    model.translation = nil
    model.answer = nil
    model.question = ""
    model.asking = false
    model.working = false
    model.problem = nil
    model.copied = nil
    place()
    panel.makeKeyAndOrderFront(nil)
  }

  func close() {
    panel.orderOut(nil)
  }

  /// Abajo en el centro de la pantalla del ratón, encima de la pastilla; crece hacia arriba.
  private func place() {
    // SwiftUI aplica los cambios del modelo más tarde: sin forzar el layout se mediría el contenido anterior.
    hosting.layoutSubtreeIfNeeded()
    let size = hosting.fittingSize
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    guard let visible = screen?.visibleFrame else { return }
    panel.setFrame(NSRect(x: visible.midX - size.width / 2, y: visible.minY + 86, width: size.width, height: size.height),
                   display: true)
  }

  private func copy(_ text: String, key: String) {
    ScreenCapture.copyText(text)
    model.copied = key
  }

  private func translate() {
    let text = model.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, !model.working else { return }
    model.working = true
    model.problem = nil
    let assistant = assistant(), preferred = preferred()
    Task {
      let translation = await assistant.translate(text, preferred: preferred)
      model.translation = translation
      model.problem = translation == nil ? "No se pudo traducir" : nil
      model.working = false
      place()
    }
  }

  /// La primera vez abre el campo de la pregunta; con una pregunta escrita, la envía.
  private func ask() {
    guard model.asking else {
      model.asking = true
      place()
      return
    }
    let question = model.question.trimmingCharacters(in: .whitespacesAndNewlines)
    let text = model.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !question.isEmpty, !text.isEmpty, !model.working else { return }
    model.working = true
    model.problem = nil
    let assistant = assistant()
    Task {
      let answer = await assistant.ask(question, about: text)
      model.answer = answer
      model.problem = answer == nil ? "No hay respuesta: sin conexión y sin el modelo del Mac" : nil
      model.working = false
      place()
    }
  }
}
