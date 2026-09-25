import SinteclaCore
import SwiftUI

/// Inicio (spec «Módulos y batería» §3.1): una tarjeta por módulo encendido con su resumen; al pulsarla se entra en
/// el módulo. Abajo, General y Módulos.
struct HomeView: View {
  @Bindable var settings: AppSettings
  let usage: UsageStatsStore
  let meetings: MeetingLibrary
  let meetingActions: MeetingActions
  let navigation: MainNavigation
  @State private var stats = UsageStats()

  var body: some View {
    let modules = settings.modules.enabled
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        if modules.isEmpty {
          ContentUnavailableView {
            Label("Sin módulos", systemImage: "square.grid.2x2")
          } description: {
            Text("Enciende algún módulo para empezar.")
          }
        } else {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
            ForEach(modules, id: \.self) { card($0) }
          }
        }
        HStack {
          Spacer()
          Button { navigation.place = .general } label: { Label("General", systemImage: "gearshape") }
          Button { navigation.place = .modules } label: { Label("Módulos", systemImage: "square.grid.2x2") }
        }
        .buttonStyle(.glass)
      }
      .padding(24)
    }
    .onAppear { stats = usage.current }
    .onReceive(NotificationCenter.default.publisher(for: .usageChanged)) { _ in stats = usage.current }
  }

  private func card(_ module: Module) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(module.name, systemImage: module.symbol).font(.title3.weight(.semibold))
      summary(module)
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
    .padding(16)
    .contentShape(RoundedRectangle(cornerRadius: 18))
    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
    .onTapGesture { if let first = module.pages.first { navigation.place = .page(first) } }
  }

  @ViewBuilder private func summary(_ module: Module) -> some View {
    let now = Date()
    switch module {
    case .dictation:
      Text(HomeSummary.dictation(uses: stats.uses(on: now), words: stats.words(on: now))).foregroundStyle(.secondary)
    case .meetings:
      Text(HomeSummary.meetings(meetings.records, now: now)).foregroundStyle(.secondary)
      Button(action: meetingActions.toggle) {
        Label(meetings.recordingSince == nil ? "Grabar reunión" : "Detener",
              systemImage: meetings.recordingSince == nil ? "record.circle" : "stop.circle.fill")
      }
      .buttonStyle(.glass)
    case .finder:
      Text("⌘X corta y ⌘V mueve archivos en Finder").foregroundStyle(.secondary)
    }
  }
}

/// Módulos: un interruptor por módulo. Uno apagado desaparece de Inicio y del menú, y deja de funcionar.
struct ModulesView: View {
  @Bindable var settings: AppSettings

  var body: some View {
    Form {
      Section {
        ForEach(Module.allCases, id: \.self) { module in
          Toggle(isOn: Binding(get: { settings.modules[module] }, set: { settings.modules[module] = $0 })) {
            Label {
              VStack(alignment: .leading, spacing: 2) {
                Text(module.name)
                Text(module.detail).font(.caption).foregroundStyle(.secondary)
              }
            } icon: {
              Image(systemName: module.symbol)
            }
          }
        }
      } footer: {
        Text("Un módulo apagado desaparece de Inicio y del menú, y deja de funcionar. Con Dictado apagado no funciona "
             + "ningún atajo de la tecla base, tampoco el de reunión: las reuniones se graban desde el menú o Inicio.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }
}
