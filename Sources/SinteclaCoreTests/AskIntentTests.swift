import Foundation
import Testing
@testable import SinteclaCore

@Suite struct IntentClassifierTests {
  @Test(arguments: [
    ("qué significa esto", true, AskIntent.question),
    ("¿de qué año es?", false, .question),
    ("explícame este párrafo", true, .question),
    ("de qué va este artículo", true, .question),
    ("hazlo más formal", true, .edit),
    ("tradúcelo al inglés", true, .edit),
    ("busca vídeos de gatos en YouTube", false, .webAction),
    ("Búscame en Amazon unos auriculares", false, .webAction),
    ("pon la última canción de Rosalía", false, .webAction),
    ("busca los errores de este texto", true, .edit),
    ("escribe un correo a Juan diciendo que llego tarde", false, .edit),
  ])
  func classifies(text: String, hasSelection: Bool, expected: AskIntent) {
    #expect(IntentClassifier.classify(text, hasSelection: hasSelection) == expected)
  }
}

@Suite struct TranslationCommandTests {
  @Test func findsTheTargetLanguage() {
    #expect(TranslationCommand.target(of: "tradúcelo al inglés") == .en)
    #expect(TranslationCommand.target(of: "Tradúceme esto al francés, por favor") == .fr)
    #expect(TranslationCommand.target(of: "traducir a castellano") == .es)
    #expect(TranslationCommand.target(of: "hazlo más formal") == nil)
    #expect(TranslationCommand.target(of: "tradúcelo") == nil)
  }

  @Test func knowsWhenACommandNamesALanguage() {
    #expect(TranslationCommand.mentionsLanguage("escríbelo en inglés"))
    #expect(!TranslationCommand.mentionsLanguage("hazlo más formal"))
  }

  @Test func detectsTheSourceLanguage() {
    #expect(TranslationCommand.language(of: "Te paso el enlace luego y lo revisamos juntos.") == .es)
    #expect(TranslationCommand.language(of: "The meeting is postponed until next week.") == .en)
  }
}

@Suite struct WebSiteTests {
  @Test func buildsEncodedSearchURLs() {
    #expect(WebSite.google.url(for: "recetas de paella").absoluteString == "https://www.google.com/search?q=recetas%20de%20paella")
    #expect(WebSite.youtube.url(for: "gatos & perros").absoluteString == "https://www.youtube.com/results?search_query=gatos%20%26%20perros")
    #expect(WebSite.amazon.url(for: "auriculares").absoluteString == "https://www.amazon.es/s?k=auriculares")
    #expect(WebSite.maps.url(for: "Retiro/Madrid").absoluteString == "https://www.google.com/maps/search/Retiro%2FMadrid")
    #expect(WebSite.wikipedia.url(for: "Imperio romano").absoluteString == "https://es.wikipedia.org/w/index.php?search=Imperio%20romano")
    #expect(WebSite.google.url(for: "canción").absoluteString == "https://www.google.com/search?q=canci%C3%B3n")
  }

  @Test func decodesGeminiReplyAndFallsBackToGoogle() {
    #expect(WebAction.decode(Data(#"{"sitio": "youtube", "consulta": "gatos"}"#.utf8)) == WebAction(site: .youtube, query: "gatos"))
    #expect(WebAction.decode(Data(#"{"sitio": "tiktok", "consulta": "gatos"}"#.utf8)) == WebAction(site: .google, query: "gatos"))
    #expect(WebAction.decode(Data(#"{"sitio": "google", "consulta": " "}"#.utf8)) == nil)
    #expect(WebAction.decode(Data("no es json".utf8)) == nil)
  }
}

@Suite struct WebActionParserTests {
  @Test(arguments: [
    ("busca vídeos de gatos en YouTube", WebSite.youtube, "vídeos de gatos"),
    ("Búscame en Amazon unos auriculares con cancelación de ruido.", .amazon, "unos auriculares con cancelación de ruido"),
    ("abre YouTube y pon la última canción de Rosalía", .youtube, "la última canción de Rosalía"),
    ("busca quién ganó el mundial de 2010", .google, "quién ganó el mundial de 2010"),
    ("enséñame en el mapa cómo llegar al Retiro", .maps, "cómo llegar al Retiro"),
    ("busca en la Wikipedia la historia de Roma", .wikipedia, "la historia de Roma"),
    ("abre Google Maps y busca farmacias cerca", .maps, "farmacias cerca"),
    ("Busca recetas de paella.", .google, "recetas de paella"),
  ])
  func parses(text: String, site: WebSite, query: String) {
    #expect(WebActionParser.parse(text) == WebAction(site: site, query: query))
  }
}
