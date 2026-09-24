import Foundation
import Testing
@testable import SinteclaCore

@Suite struct SiteRulesTests {
  @Test(arguments: [
    ("https://www.LinkedIn.com/feed/", "linkedin.com"),
    ("mail.google.com", "mail.google.com"),
    ("  web.whatsapp.com \n", "web.whatsapp.com"),
    ("http://intranet.brisenta.es:8080/x?y#z", "intranet.brisenta.es"),
    ("WWW.GitHub.com", "github.com"),
    ("docs.google.com/document/d/123", "docs.google.com"),
  ])
  func normalizes(input: String, expected: String) {
    #expect(SiteRules.normalize(input) == expected)
  }

  @Test(arguments: ["hola", "", "   ", ".com", "google.", "google..com", "mañana.es", "a b.com", "https://"])
  func rejects(_ input: String) {
    #expect(SiteRules.normalize(input) == nil)
  }

  @Test func matchesTheDomainAndItsSubdomains() {
    let sites = ["slack.com", "mail.google.com", "google.com", "gemini.google.com"]
    #expect(SiteRules.match("slack.com", in: sites) == "slack.com")
    #expect(SiteRules.match("miempresa.slack.com", in: sites) == "slack.com")
    #expect(SiteRules.match("notslack.com", in: sites) == nil)
    #expect(SiteRules.match("slack.com", in: [String]()) == nil)
  }

  @Test func theLongestRuleWins() {
    let sites = ["google.com", "mail.google.com", "gemini.google.com"]
    #expect(SiteRules.match("gemini.google.com", in: sites) == "gemini.google.com")
    #expect(SiteRules.match("mail.google.com", in: sites) == "mail.google.com")
    // Un sufijo que no es subdominio no cuenta: cae en la regla del padre.
    #expect(SiteRules.match("xmail.google.com", in: sites) == "google.com")
  }
}

@Suite struct ToneBySiteTests {
  let safari = "com.apple.Safari"

  @Test func safariUsesTheToneOfTheSite() {
    let rules = ToneRules.defaults
    #expect(rules.tone(for: safari, host: "mail.google.com") == .formal)
    #expect(rules.tone(for: safari, host: "web.whatsapp.com") == .informal)
    #expect(rules.tone(for: safari, host: "miempresa.slack.com") == .informal)
    #expect(rules.tone(for: safari, host: "github.com") == .technical)
  }

  @Test func aSiteNotInTheListUsesTheToneOfSafari() {
    var rules = ToneRules.defaults
    #expect(rules.tone(for: safari, host: "es.wikipedia.org") == .neutral)
    rules.byBundleID[safari] = .formal
    #expect(rules.tone(for: safari, host: "es.wikipedia.org") == .formal)
    #expect(rules.tone(for: safari, host: nil) == .formal)
  }

  @Test func theSiteOnlyCountsInSafari() {
    let rules = ToneRules.defaults
    #expect(rules.tone(for: "com.apple.mail", host: "web.whatsapp.com") == .formal)
    #expect(rules.tone(for: nil, host: "web.whatsapp.com") == .neutral)
  }

  @Test func anOldTonesFileGetsTheInitialSites() throws {
    let old = #"{"byBundleID":{"com.apple.Safari":"formal","net.whatsapp.WhatsApp":"informal"}}"#
    let rules = try JSONDecoder().decode(ToneRules.self, from: Data(old.utf8))
    #expect(rules.byBundleID == ["com.apple.Safari": .formal, "net.whatsapp.WhatsApp": .informal])
    #expect(rules.bySite == ToneRules.defaults.bySite)
  }

  @Test func anEmptySiteListIsKept() throws {
    var rules = ToneRules.defaults
    rules.bySite = [:]
    let decoded = try JSONDecoder().decode(ToneRules.self, from: JSONEncoder().encode(rules))
    #expect(decoded == rules)
  }
}
