import Foundation
import SinteclaCore

/// Clave de Gemini en el Llavero (servicio `local.sintecla.app`, cuenta `gemini`).
///
/// Se usa la herramienta de Apple `/usr/bin/security` en vez de la API del Llavero: la app va
/// firmada ad hoc y cada compilación tiene otro hash, así que macOS le negaría su propia clave
/// (y pediría la contraseña del Mac) tras cada recompilación (probado). La clave se envía por
/// stdin en hexadecimal, nunca en los argumentos, que cualquiera puede ver con `ps`.
enum Keychain {
  static let service = AppInfo.bundleID
  static let geminiAccount = "gemini"

  static func read(account: String) -> String? {
    let result = run(["find-generic-password", "-s", service, "-a", account, "-w"])
    guard result.status == 0 else { return nil }
    let value = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }

  /// Crea o reemplaza la entrada. Devuelve si se pudo leer después.
  @discardableResult
  static func save(_ value: String, account: String) -> Bool {
    let hex = Data(value.utf8).map { String(format: "%02x", $0) }.joined()
    run(["-i"], input: "add-generic-password -U -s \(service) -a \(account) -l Sintecla -X \(hex)\n")
    return read(account: account) == value
  }

  static func delete(account: String) {
    run(["delete-generic-password", "-s", service, "-a", account])
  }

  @discardableResult
  private static func run(_ arguments: [String], input: String? = nil) -> (status: Int32, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    process.arguments = arguments
    let output = Pipe(), stdin = Pipe()
    process.standardOutput = output
    process.standardError = Pipe()
    process.standardInput = stdin
    do { try process.run() } catch { return (-1, "") }
    if let input { stdin.fileHandleForWriting.write(Data(input.utf8)) }
    try? stdin.fileHandleForWriting.close()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, String(decoding: data, as: UTF8.self))
  }
}
