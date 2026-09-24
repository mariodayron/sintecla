import Charts
import SinteclaCore
import SwiftUI

extension Notification.Name {
  /// Se ha sumado un uso a las estadísticas.
  static let usageChanged = Notification.Name("SinteclaUsageChanged")
}

/// Sección Estadísticas: cifras, gráfica y reparto por app y por modo, con el resumen de `stats.json`.
struct StatsView: View {
  let store: UsageStatsStore
  @State private var stats = UsageStats()
  @State private var scale: UsageStats.Scale = .days
  @State private var period: UsageStats.Period = .month

  var body: some View {
    let now = Date()
    Group {
      if stats.totalUses == 0 {
        ContentUnavailableView("Aún no hay dictados", systemImage: "chart.bar",
                               description: Text("Cuando dictes, aquí verás cuánto, cuándo y dónde."))
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            if let first = stats.firstDay() {
              Text("Desde el \(first.formatted(.dateTime.day().month(.wide))) · \(stats.totalUses.formatted()) usos")
                .font(.caption).foregroundStyle(.secondary)
            }
            figures(now: now)
            chart(now: now)
            Picker("Periodo", selection: $period) {
              Text("7 días").tag(UsageStats.Period.week)
              Text("30 días").tag(UsageStats.Period.month)
              Text("Siempre").tag(UsageStats.Period.all)
            }
            .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 260)
            HStack(alignment: .top, spacing: 12) {
              shares("Por app", stats.byApp(period, now: now))
              shares("Por modo", stats.byMode(period, now: now))
            }
            Text("\(stats.wordsPerMinute) palabras/min al dictar · \(stats.totalWords.formatted()) palabras en total")
              .font(.caption).foregroundStyle(.secondary)
          }
          .padding(20)
        }
      }
    }
    .onAppear { stats = store.current }
    .onReceive(NotificationCenter.default.publisher(for: .usageChanged)) { _ in stats = store.current }
  }

  private func figures(now: Date) -> some View {
    let best = stats.bestDay()
    return HStack(spacing: 12) {
      figure("Hoy", stats.words(on: now).formatted(), "palabras")
      figure("Racha", stats.streak(now: now) == 1 ? "1 día" : "\(stats.streak(now: now)) días",
             "récord: \(stats.recordStreak())")
      figure("Tiempo ahorrado", Self.duration(minutes: stats.minutesSaved), "frente a teclear")
      figure("Mejor día", best.map { $0.words.formatted() } ?? "—",
             best.map { $0.start.formatted(.dateTime.day().month(.abbreviated)) } ?? "")
    }
  }

  private func figure(_ title: String, _ value: String, _ detail: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      Text(value).font(.title2.weight(.semibold)).monospacedDigit()
      Text(detail).font(.caption2).foregroundStyle(.tertiary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
  }

  private func chart(now: Date) -> some View {
    let bars = stats.series(scale, now: now)
    let most = bars.map(\.words).max() ?? 0
    let unit: Calendar.Component = switch scale {
    case .days: .day
    case .weeks: .weekOfYear
    case .months: .month
    }
    return VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Palabras").font(.headline)
        Spacer()
        Picker("Escala", selection: $scale) {
          Text("Días").tag(UsageStats.Scale.days)
          Text("Semanas").tag(UsageStats.Scale.weeks)
          Text("Meses").tag(UsageStats.Scale.months)
        }
        .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 240)
      }
      Chart(bars, id: \.start) { bar in
        BarMark(x: .value("Periodo", bar.start, unit: unit), y: .value("Palabras", bar.words))
          .foregroundStyle(bar.words == most && most > 0 ? Color.primary : Color.secondary.opacity(0.6))
          .cornerRadius(3)
      }
      .frame(height: 170)
    }
    .padding(12)
    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
  }

  private func shares(_ title: String, _ rows: [UsageStats.Share]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.headline)
      if rows.isEmpty {
        Text("Aún no hay dictados en este periodo").font(.caption).foregroundStyle(.secondary)
      }
      ForEach(rows, id: \.name) { row in
        HStack(spacing: 8) {
          Text(row.name).lineLimit(1).frame(width: 90, alignment: .leading)
          Capsule().fill(.quaternary).frame(height: 6)
            .overlay(alignment: .leading) {
              GeometryReader { box in Capsule().fill(.secondary).frame(width: box.size.width * row.fraction) }
            }
          Text(row.fraction.formatted(.percent.precision(.fractionLength(0))))
            .monospacedDigit().foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
        }
        .font(.caption)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
  }

  /// «18 h 40 min», «25 min».
  static func duration(minutes: Int) -> String {
    minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
  }
}
