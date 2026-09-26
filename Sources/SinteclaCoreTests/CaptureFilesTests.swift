import Foundation
import Testing
@testable import SinteclaCore

@Suite struct CaptureFilesTests {
  private let madrid = TimeZone(identifier: "Europe/Madrid")!

  private func date() throws -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = madrid
    return try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 10, minute: 42, second: 13)))
  }

  @Test func nameLikeMacOS() throws {
    #expect(CaptureFiles.name(for: try date(), timeZone: madrid) == "Captura 2026-09-26 a las 10.42.13.png")
  }

  @Test func freeNameWhenOneAlreadyExists() throws {
    let folder = URL(fileURLWithPath: "/tmp/capturas", isDirectory: true)
    let taken: Set<String> = ["Captura 2026-09-26 a las 10.42.13.png", "Captura 2026-09-26 a las 10.42.13 2.png"]
    let exists: (URL) -> Bool = { taken.contains($0.lastPathComponent) }
    #expect(CaptureFiles.freeURL(in: folder, for: try date(), timeZone: madrid, exists: { _ in false }).lastPathComponent
            == "Captura 2026-09-26 a las 10.42.13.png")
    let url = CaptureFiles.freeURL(in: folder, for: try date(), timeZone: madrid, exists: exists)
    #expect(url.lastPathComponent == "Captura 2026-09-26 a las 10.42.13 3.png")
    #expect(url.deletingLastPathComponent().path == "/tmp/capturas")
  }

  @Test func saveNotices() {
    #expect(CaptureNotice.saved("Escritorio") == "Guardada en Escritorio")
    #expect(CaptureNotice.saveFailed == "No se pudo guardar")
  }
}
