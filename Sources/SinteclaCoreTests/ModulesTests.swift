import Foundation
import Testing
@testable import SinteclaCore

@Suite struct ModulesTests {
  let allOn = ModuleSwitches(dictation: true, meetings: true, finder: true)

  @Test func eachPageBelongsToItsModule() {
    #expect(Module.dictation.pages == [.history, .stats, .dictionary, .tones, .ai, .hotkeys])
    #expect(Module.meetings.pages == [.meetings])
    #expect(Module.finder.pages == [.finderCut])
    for module in Module.allCases {
      #expect(module.pages.allSatisfy { $0.module == module })
    }
    #expect(ModulePage.allCases.count == Module.allCases.map(\.pages.count).reduce(0, +))
  }

  @Test func namesInSpanish() {
    #expect(Module.allCases.map(\.name) == ["Dictado", "Reuniones", "Finder"])
    #expect(ModulePage.hotkeys.title == "Atajos e idioma")
    #expect(ModulePage.finderCut.title == "Cortar y pegar")
  }

  @Test func enabledModulesKeepTheirOrder() {
    #expect(allOn.enabled == [.dictation, .meetings, .finder])
    #expect(ModuleSwitches(dictation: false, meetings: true, finder: true).enabled == [.meetings, .finder])
    #expect(ModuleSwitches(dictation: false, meetings: false, finder: false).enabled == [])
  }

  @Test func switchesCanBeReadAndChangedByModule() {
    var switches = allOn
    switches[.meetings] = false
    #expect(!switches[.meetings])
    #expect(switches[.dictation] && switches[.finder])
  }

  @Test func pageOfATurnedOffModuleGoesHome() {
    let noDictation = ModuleSwitches(dictation: false, meetings: true, finder: false)
    #expect(WindowPlace.page(.history).resolved(with: noDictation) == .home)
    #expect(WindowPlace.page(.finderCut).resolved(with: noDictation) == .home)
    #expect(WindowPlace.page(.meetings).resolved(with: noDictation) == .page(.meetings))
    #expect(WindowPlace.general.resolved(with: noDictation) == .general)
    #expect(WindowPlace.modules.resolved(with: noDictation) == .modules)
  }

  @Test func placeKnowsItsModule() {
    #expect(WindowPlace.page(.tones).module == .dictation)
    #expect(WindowPlace.home.module == nil)
    #expect(WindowPlace.general.module == nil)
  }

  @Test func dictationSummary() {
    #expect(HomeSummary.dictation(uses: 0, words: 0) == "Aún no has dictado hoy")
    #expect(HomeSummary.dictation(uses: 1, words: 1) == "1 dictado · 1 palabra hoy")
    #expect(HomeSummary.dictation(uses: 12, words: 840) == "12 dictados · 840 palabras hoy")
  }

  @Test func meetingsSummaryCountsThisWeekAndPending() {
    let now = Date(timeIntervalSince1970: 1_790_000_000)
    let day: TimeInterval = 86_400
    let records = [
      MeetingRecord(id: "a", startedAt: now - 1 * day, status: .ready),
      MeetingRecord(id: "b", startedAt: now - 6 * day, status: .ready),
      MeetingRecord(id: "c", startedAt: now - 8 * day, status: .ready),  // hace más de 7 días
      MeetingRecord(id: "d", startedAt: now - 2 * day, status: .pending),
      MeetingRecord(id: "e", startedAt: now - 20 * day, status: .pending),  // pendiente: cuenta aunque sea antigua
      MeetingRecord(id: "f", startedAt: now, status: .recording),
    ]
    #expect(HomeSummary.meetings(records, now: now) == "2 actas esta semana · 2 pendientes")
    #expect(HomeSummary.meetings([records[0]], now: now) == "1 acta esta semana")
    #expect(HomeSummary.meetings([], now: now) == "Sin actas esta semana")
    #expect(HomeSummary.meetings([records[3]], now: now) == "Sin actas esta semana · 1 pendiente")
  }

  @Test func usesOnADay() {
    let calendar = Calendar(identifier: .gregorian)
    let date = Date(timeIntervalSince1970: 1_790_000_000)
    var stats = UsageStats()
    for text in ["hola qué tal", "otra cosa"] {
      stats.add(HistoryEntry(date: date, mode: .dictation, appBundleID: nil, appName: nil, language: "es_ES",
                             audioSeconds: 2, rawText: text, finalText: text, engine: "rules", latencyMs: 10),
                calendar: calendar)
    }
    #expect(stats.uses(on: date, calendar: calendar) == 2)
    #expect(stats.uses(on: date + 86_400 * 2, calendar: calendar) == 0)
  }
}
