import AppKit
import Foundation

/// Rutas de datos: ~/Library/Application Support/Sintecla/
public enum AppPaths {
  public static var supportDirectory: URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let dir = base.appendingPathComponent("Sintecla", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  public static var historyURL: URL { supportDirectory.appendingPathComponent("history.jsonl") }
  public static var statsURL: URL { supportDirectory.appendingPathComponent("stats.json") }
  public static var dictionaryURL: URL { supportDirectory.appendingPathComponent("dictionary.json") }
  public static var tonesURL: URL { supportDirectory.appendingPathComponent("tones.json") }
  public static var draftsDirectory: URL { supportDirectory.appendingPathComponent("drafts", isDirectory: true) }
  public static var meetingsDirectory: URL { supportDirectory.appendingPathComponent("meetings", isDirectory: true) }
  /// Actas en PDF y Markdown: ~/Documents/Sintecla/Reuniones/
  public static var minutesDirectory: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Sintecla/Reuniones", isDirectory: true)
  }
}

/// Guardar y cargar cualquier `Codable` como JSON legible.
public enum JSONFileStore {
  public static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
  }

  public static func save<T: Encodable>(_ value: T, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try encoder.encode(value).write(to: url, options: .atomic)
  }
}

/// ¿Existe la palabra en español o inglés? Usa el corrector del sistema.
public enum SpellChecker {
  public static func isKnownWord(_ word: String) -> Bool {
    let check: () -> Bool = {
      let checker = NSSpellChecker.shared
      for language in ["es", "en"] {
        let miss = checker.checkSpelling(of: word, startingAt: 0, language: language, wrap: false,
                                         inSpellDocumentWithTag: 0, wordCount: nil)
        if miss.location == NSNotFound { return true }
      }
      return false
    }
    // NSSpellChecker debe usarse en el hilo principal.
    if Thread.isMainThread { return check() }
    return DispatchQueue.main.sync(execute: check)
  }
}
