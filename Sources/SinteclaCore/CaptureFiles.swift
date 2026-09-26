import Foundation

/// Los archivos de las capturas guardadas (spec «Editor de capturas completo» §4).
public enum CaptureFiles {
  /// «Captura 2026-09-26 a las 10.42.13.png», con la fecha y la hora de la captura, como las de macOS.
  public static func name(for date: Date, timeZone: TimeZone = .current) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy-MM-dd 'a las' HH.mm.ss"
    return "Captura \(formatter.string(from: date)).png"
  }

  /// En `folder`, con ese nombre o, si ya existe, con « 2», « 3»…
  public static func freeURL(in folder: URL, for date: Date, timeZone: TimeZone = .current,
                             exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) -> URL {
    let base = String(name(for: date, timeZone: timeZone).dropLast(".png".count))
    var url = folder.appendingPathComponent(base + ".png")
    var number = 2
    while exists(url) {
      url = folder.appendingPathComponent("\(base) \(number).png")
      number += 1
    }
    return url
  }
}
