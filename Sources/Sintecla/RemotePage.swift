import AppKit
import SinteclaCore
import SwiftUI

/// Mando → Mando: encenderlo, el QR para el móvil y el aviso de seguridad.
struct RemotePage: View {
  @Bindable var settings: AppSettings
  private let remote = RemoteController.shared
  @State private var copied = false

  var body: some View {
    Form {
      Section {
        HStack(spacing: 14) {
          Image(systemName: "iphone.radiowaves.left.and.right")
            .font(.system(size: 28))
            .foregroundStyle(remote.state == .on ? .green : .secondary)
          VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.headline)
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
          }
          Spacer()
          Button(remote.isOn ? "Apagar" : "Encender", action: remote.toggle)
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
        .padding(.vertical, 4)
        Toggle("Encender al abrir Sintecla", isOn: $settings.remoteAlwaysOn)
        if case .failed(let reason) = remote.state {
          Label(reason, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
        }
      }

      if remote.state == .on {
        Section("Conecta el móvil") {
          HStack(alignment: .top, spacing: 20) {
            if let qr = RemoteController.qrCode(for: remote.link, side: 180) {
              Image(nsImage: qr)
                .interpolation(.none)
                .frame(width: 180, height: 180)
                .padding(10)
                .background(.white, in: .rect(cornerRadius: 14))
            }
            VStack(alignment: .leading, spacing: 10) {
              Text("1. El móvil en la misma Wi-Fi que el Mac.")
              Text("2. Escanea el QR con la cámara y abre el enlace.")
              Text("3. En Safari, Compartir → «Añadir a pantalla de inicio»: queda como una app, con la llave "
                   + "guardada. Con «Encender al abrir Sintecla», siempre conecta.")
              Divider()
              Text(remote.link).font(.caption.monospaced()).textSelection(.enabled).lineLimit(2)
              if let ipLink = remote.ipLink {
                Text("Si no conecta: \(ipLink)").font(.caption.monospaced()).foregroundStyle(.secondary)
                  .textSelection(.enabled).lineLimit(2)
              }
              Button(copied ? "Copiado" : "Copiar enlace") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(remote.link, forType: .string)
                copied = true
              }
            }
            .font(.callout)
          }
          .padding(.vertical, 6)
        }
      }

      Section("Qué hace") {
        LabeledContent("Trackpad", value: "Un dedo mueve, toque = clic, doble toque = doble clic, dos dedos desplazan")
        LabeledContent("Mando", value: "Música (⏯ y ±10 s), volumen, escribir en el Mac, brillo, Spotlight y reposo")
        LabeledContent("Pestañas", value: "Pantalla completa, cerrar pestaña y abrir Netflix, YouTube y demás")
      }

      Section("Seguridad") {
        Text("Mientras está encendido, cualquiera con el enlace y en tu misma Wi-Fi puede mover tu Mac. Úsalo solo "
             + "en redes de confianza y apágalo al terminar. El enlace lleva una llave: sin ella no hace nada.")
          .font(.callout).foregroundStyle(.secondary)
        Button("Cambiar el enlace (desconecta los móviles de antes)") { remote.newLink() }
      }
    }
    .formStyle(.grouped)
  }

  private var title: String {
    switch remote.state {
    case .on: "Encendido"
    case .starting: "Encendiendo…"
    case .off, .failed: "Apagado"
    }
  }

  private var subtitle: String {
    switch remote.state {
    case .on:
      remote.clients == 0 ? "Esperando al móvil"
        : "\(remote.clients) \(remote.clients == 1 ? "móvil conectado" : "móviles conectados")"
    case .starting: "Abriendo el puerto \(remote.port)"
    case .off, .failed: "El móvil como trackpad y mando del Mac"
    }
  }
}
