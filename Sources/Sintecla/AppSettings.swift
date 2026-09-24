import Foundation
import Observation
import SinteclaCore

/// Ajustes de la app. Los simples van a UserDefaults; diccionario y tonos, a JSON;
/// la clave de Gemini, al Llavero.
@MainActor @Observable
final class AppSettings {
  @ObservationIgnored private let defaults = UserDefaults.standard

  var language: String { didSet { defaults.set(language, forKey: "language") } }
  var whisperMode: Bool { didSet { defaults.set(whisperMode, forKey: "whisperMode") } }
  var soundsEnabled: Bool { didSet { defaults.set(soundsEnabled, forKey: "soundsEnabled") } }
  var baseKey: BaseKey { didSet { defaults.set(baseKey.rawValue, forKey: "baseKey") } }
  /// Qué tecla acompaña a la base en cada modo (F4c).
  var hotkeys: HotkeyLayout { didSet { defaults.set(try? JSONEncoder().encode(hotkeys), forKey: "hotkeys") } }
  var launchAtLogin: Bool { didSet { defaults.set(launchAtLogin, forKey: "launchAtLogin") } }
  var translationTarget: TranslationLanguage { didSet { defaults.set(translationTarget.rawValue, forKey: "translationTarget") } }
  var geminiModel: String { didSet { defaults.set(geminiModel, forKey: "geminiModel") } }
  /// "Mi estilo": se añade a las instrucciones de edición y de notas.
  var myStyle: String { didSet { defaults.set(myStyle, forKey: "myStyle") } }
  /// Con clave, ordenar el dictado con Gemini (spec «Ordenar el dictado»). Apagado: siempre en el Mac.
  var cleanWithGemini: Bool { didSet { defaults.set(cleanWithGemini, forKey: "cleanWithGemini") } }
  /// Tras pegar, mirar si el usuario corrige alguna palabra y aprenderla (F4a).
  var learnCorrections: Bool { didSet { defaults.set(learnCorrections, forKey: "learnCorrections") } }
  /// Reuniones: guardar también el audio (mic.m4a y sistema.m4a) junto a la transcripción.
  var saveMeetingAudio: Bool { didSet { defaults.set(saveMeetingAudio, forKey: "saveMeetingAudio") } }
  /// El aviso de "informa a los participantes" ya se mostró (sale la primera vez que se graba).
  var meetingNoticeShown: Bool { didSet { defaults.set(meetingNoticeShown, forKey: "meetingNoticeShown") } }
  var dictionary: PersonalDictionary { didSet { try? JSONFileStore.save(dictionary, to: AppPaths.dictionaryURL) } }
  var tones: ToneRules { didSet { try? JSONFileStore.save(tones, to: AppPaths.tonesURL) } }
  /// Vacía si no hay clave. Se cambia con `setGeminiKey(_:)`.
  private(set) var geminiKey: String

  init() {
    defaults.register(defaults: [
      "language": "es_ES", "whisperMode": false, "soundsEnabled": true,
      "baseKey": BaseKey.fn.rawValue, "launchAtLogin": true,
      "translationTarget": TranslationLanguage.en.rawValue, "geminiModel": CloudConfig.defaultModel, "myStyle": "",
      "cleanWithGemini": true,
      "learnCorrections": true,
      "saveMeetingAudio": true, "meetingNoticeShown": false,
    ])
    language = defaults.string(forKey: "language") ?? "es_ES"
    whisperMode = defaults.bool(forKey: "whisperMode")
    soundsEnabled = defaults.bool(forKey: "soundsEnabled")
    baseKey = BaseKey(rawValue: defaults.string(forKey: "baseKey") ?? "") ?? .fn
    hotkeys = HotkeyLayout.decoded(defaults.data(forKey: "hotkeys"))
    launchAtLogin = defaults.bool(forKey: "launchAtLogin")
    translationTarget = TranslationLanguage(rawValue: defaults.string(forKey: "translationTarget") ?? "") ?? .en
    geminiModel = defaults.string(forKey: "geminiModel") ?? CloudConfig.defaultModel
    myStyle = defaults.string(forKey: "myStyle") ?? ""
    cleanWithGemini = defaults.bool(forKey: "cleanWithGemini")
    learnCorrections = defaults.bool(forKey: "learnCorrections")
    saveMeetingAudio = defaults.bool(forKey: "saveMeetingAudio")
    meetingNoticeShown = defaults.bool(forKey: "meetingNoticeShown")
    dictionary = JSONFileStore.load(PersonalDictionary.self, from: AppPaths.dictionaryURL) ?? PersonalDictionary()
    tones = JSONFileStore.load(ToneRules.self, from: AppPaths.tonesURL) ?? .defaults
    geminiKey = Keychain.read(account: Keychain.geminiAccount) ?? ""
  }

  /// Guarda la clave en el Llavero (o la borra si llega vacía). Devuelve false si no se pudo guardar.
  @discardableResult
  func setGeminiKey(_ key: String) -> Bool {
    let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
    if key.isEmpty {
      Keychain.delete(account: Keychain.geminiAccount)
      geminiKey = ""
      return true
    }
    guard Keychain.save(key, account: Keychain.geminiAccount) else { return false }
    geminiKey = key
    return true
  }

  /// Gemini listo para usar, o nil si no hay clave. `timeout`: 30 s en general, 120 s en notas.
  func cloudModel(timeout: TimeInterval = 30) -> CloudTextModel? {
    guard !geminiKey.isEmpty else { return nil }
    let model = geminiModel.trimmingCharacters(in: .whitespaces)
    return CloudTextModel(config: CloudConfig(model: model.isEmpty ? CloudConfig.defaultModel : model,
                                              apiKey: geminiKey, timeout: timeout))
  }
}
