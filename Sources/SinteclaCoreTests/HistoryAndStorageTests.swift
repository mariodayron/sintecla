import Foundation
import Testing
@testable import SinteclaCore

@Suite struct HistoryStoreTests {
  func tempURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("sintecla-tests-\(UUID().uuidString)")
      .appendingPathComponent("history.jsonl")
  }

  func entry(_ text: String, date: Date, seconds: Double = 10) -> HistoryEntry {
    HistoryEntry(date: date, mode: .dictation, appBundleID: "com.apple.mail", appName: "Mail", language: "es_ES",
                 audioSeconds: seconds, rawText: text, finalText: text, engine: "apple", latencyMs: 400)
  }

  @Test func appendsAndLoadsNewestFirst() throws {
    let store = HistoryStore(fileURL: tempURL())
    let a = entry("uno dos", date: Date(timeIntervalSince1970: 1_700_000_000))
    let b = entry("tres cuatro cinco", date: Date(timeIntervalSince1970: 1_700_000_100))
    try store.append(a)
    try store.append(b)
    #expect(store.load() == [b, a])
    #expect(store.latest() == b)
  }

  @Test func compactKeepsMostRecent() throws {
    let store = HistoryStore(fileURL: tempURL(), maxEntries: 2)
    for i in 0..<5 {
      try store.append(entry("entrada \(i)", date: Date(timeIntervalSince1970: 1_700_000_000 + Double(i))))
    }
    try store.compact()
    #expect(store.load().map(\.finalText) == ["entrada 4", "entrada 3"])
  }

  @Test func ignoresCorruptLines() throws {
    let url = tempURL()
    let store = HistoryStore(fileURL: url)
    try store.append(entry("bien", date: Date(timeIntervalSince1970: 1_700_000_000)))
    let handle = try FileHandle(forWritingTo: url)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data("{roto\n".utf8))
    try handle.close()
    #expect(store.load().count == 1)
  }
}

@Suite struct JSONFileStoreTests {
  @Test func roundTripsDictionary() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("dict-\(UUID().uuidString).json")
    let d = PersonalDictionary(terms: ["Brisenta"], rules: [DictionaryRule(from: "bri senta", to: "Brisenta")])
    try JSONFileStore.save(d, to: url)
    #expect(JSONFileStore.load(PersonalDictionary.self, from: url) == d)
    #expect(JSONFileStore.load(PersonalDictionary.self, from: url.appendingPathExtension("nope")) == nil)
  }
}

@Suite struct SpellCheckerTests {
  @Test func knowsRealWordsAndRejectsInventedOnes() {
    #expect(SpellChecker.isKnownWord("brisa"))
    #expect(SpellChecker.isKnownWord("meeting"))
    #expect(!SpellChecker.isKnownWord("brosanta"))
    #expect(!SpellChecker.isKnownWord("supabeis"))
  }
}
