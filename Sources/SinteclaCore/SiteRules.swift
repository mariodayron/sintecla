import Foundation

/// Tono por web: dominios de la lista y regla que corresponde a la pestaña de Safari.
public enum SiteRules {
  /// Apps donde cuenta el tono por web.
  public static let browsers: Set<String> = ["com.apple.Safari"]

  /// Dominio de una dirección o de lo que escribe el usuario: sin esquema, ruta, puerto ni `www.` inicial.
  /// nil si no parece un dominio (sin punto, con espacios o caracteres raros).
  public static func normalize(_ text: String) -> String? {
    var s = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if let scheme = s.range(of: "://") { s = String(s[scheme.upperBound...]) }
    s = String(s.prefix { !"/?#".contains($0) })
    s = String(s.prefix { $0 != ":" })
    if s.hasPrefix("www.") { s.removeFirst(4) }
    let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789.-")
    guard s.contains("."), !s.hasPrefix("."), !s.hasSuffix("."), !s.contains(".."),
          s.allSatisfy(allowed.contains) else { return nil }
    return s
  }

  /// La regla que vale para `host`: su dominio o uno de sus padres (`slack.com` cubre `miempresa.slack.com`).
  /// Si hay varias, la más larga.
  public static func match(_ host: String, in sites: some Collection<String>) -> String? {
    sites.filter { host == $0 || host.hasSuffix("." + $0) }.max { $0.count < $1.count }
  }
}
