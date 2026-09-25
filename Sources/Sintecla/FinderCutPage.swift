import SwiftUI

/// Finder → Cortar y pegar (spec «Herramientas» §2). Se enciende y se apaga en Módulos; aquí se explica cómo va.
struct FinderCutPage: View {
  var body: some View {
    Form {
      Section("Cómo funciona") {
        LabeledContent("⌘X", value: "Corta los archivos seleccionados")
        LabeledContent("⌘V", value: "Los mueve a la carpeta abierta, también a otro disco")
        Text("Al renombrar, en el buscador o en «Ir a la carpeta», ⌘X y ⌘V cortan y pegan texto como siempre. "
             + "Si copias otra cosa después de cortar, ⌘V pega lo copiado y los archivos no se mueven.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }
}
