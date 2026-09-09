//
//  SubtitleLanguage.swift
//  iina
//
//  Created for IINA Smart Subtitles.
//

import Foundation

public struct SubtitleLanguage: Identifiable, Hashable {
  public var id: String { code }
  public let code: String       // 3-letter ISO 639-2/T code, e.g. "fra"
  public let iso639_1: String   // 2-letter ISO 639-1 code, e.g. "fr"
  public let iso639_2b: String? // Alternative 3-letter ISO 639-2/B code, e.g. "fre"
  public let name: String       // English display name
  public let nativeName: String // Native language name
  public let flag: String       // Flag emoji

  public init(code: String, iso639_1: String, iso639_2b: String? = nil, name: String, nativeName: String, flag: String) {
    self.code = code
    self.iso639_1 = iso639_1
    self.iso639_2b = iso639_2b
    self.name = name
    self.nativeName = nativeName
    self.flag = flag
  }
}

public final class SubtitleLanguageRegistry {
  public static let shared = SubtitleLanguageRegistry()

  public let languages: [SubtitleLanguage] = [
    SubtitleLanguage(code: "eng", iso639_1: "en", name: "English", nativeName: "English", flag: "🇬🇧"),
    SubtitleLanguage(code: "fra", iso639_1: "fr", iso639_2b: "fre", name: "French", nativeName: "Français", flag: "🇫🇷"),
    SubtitleLanguage(code: "spa", iso639_1: "es", name: "Spanish", nativeName: "Español", flag: "🇪🇸"),
    SubtitleLanguage(code: "ara", iso639_1: "ar", name: "Arabic", nativeName: "العربية", flag: "🇸🇦"),
    SubtitleLanguage(code: "deu", iso639_1: "de", iso639_2b: "ger", name: "German", nativeName: "Deutsch", flag: "🇩🇪"),
    SubtitleLanguage(code: "ita", iso639_1: "it", name: "Italian", nativeName: "Italiano", flag: "🇮🇹"),
    SubtitleLanguage(code: "por", iso639_1: "pt", name: "Portuguese", nativeName: "Português", flag: "🇵🇹"),
    SubtitleLanguage(code: "pob", iso639_1: "pb", name: "Brazilian Portuguese", nativeName: "Português (Brasil)", flag: "🇧🇷"),
    SubtitleLanguage(code: "jpn", iso639_1: "ja", name: "Japanese", nativeName: "日本語", flag: "🇯🇵"),
    SubtitleLanguage(code: "kor", iso639_1: "ko", name: "Korean", nativeName: "한국어", flag: "🇰🇷"),
    SubtitleLanguage(code: "zho", iso639_1: "zh", iso639_2b: "chi", name: "Chinese", nativeName: "中文", flag: "🇨🇳"),
    SubtitleLanguage(code: "tur", iso639_1: "tr", name: "Turkish", nativeName: "Türkçe", flag: "🇹🇷"),
    SubtitleLanguage(code: "nld", iso639_1: "nl", iso639_2b: "dut", name: "Dutch", nativeName: "Nederlands", flag: "🇳🇱"),
    SubtitleLanguage(code: "pol", iso639_1: "pl", name: "Polish", nativeName: "Polski", flag: "🇵🇱"),
    SubtitleLanguage(code: "rus", iso639_1: "ru", name: "Russian", nativeName: "Русский", flag: "🇷🇺"),
    SubtitleLanguage(code: "ukr", iso639_1: "uk", name: "Ukrainian", nativeName: "Українська", flag: "🇺🇦"),
    SubtitleLanguage(code: "swe", iso639_1: "sv", name: "Swedish", nativeName: "Svenska", flag: "🇸🇪"),
    SubtitleLanguage(code: "nor", iso639_1: "no", name: "Norwegian", nativeName: "Norsk", flag: "🇳🇴"),
    SubtitleLanguage(code: "dan", iso639_1: "da", name: "Danish", nativeName: "Dansk", flag: "🇩🇰"),
    SubtitleLanguage(code: "fin", iso639_1: "fi", name: "Finnish", nativeName: "Suomi", flag: "🇫🇮"),
    SubtitleLanguage(code: "ell", iso639_1: "el", iso639_2b: "gre", name: "Greek", nativeName: "Ελληνικά", flag: "🇬🇷"),
    SubtitleLanguage(code: "ces", iso639_1: "cs", iso639_2b: "cze", name: "Czech", nativeName: "Čeština", flag: "🇨🇿"),
    SubtitleLanguage(code: "hun", iso639_1: "hu", name: "Hungarian", nativeName: "Magyar", flag: "🇭🇺"),
    SubtitleLanguage(code: "ron", iso639_1: "ro", iso639_2b: "rum", name: "Romanian", nativeName: "Română", flag: "🇷🇴"),
    SubtitleLanguage(code: "vie", iso639_1: "vi", name: "Vietnamese", nativeName: "Tiếng Việt", flag: "🇻🇳"),
    SubtitleLanguage(code: "tha", iso639_1: "th", name: "Thai", nativeName: "ไทย", flag: "🇹🇭"),
    SubtitleLanguage(code: "ind", iso639_1: "id", name: "Indonesian", nativeName: "Bahasa Indonesia", flag: "🇮🇩"),
    SubtitleLanguage(code: "heb", iso639_1: "he", name: "Hebrew", nativeName: "עברית", flag: "🇮🇱"),
    SubtitleLanguage(code: "hin", iso639_1: "hi", name: "Hindi", nativeName: "हिन्दी", flag: "🇮🇳"),
    SubtitleLanguage(code: "fas", iso639_1: "fa", iso639_2b: "per", name: "Persian", nativeName: "فارسی", flag: "🇮🇷")
  ]

  /// Normalizes any language code, ISO code, or name to 3-letter ISO 639-2 code (e.g. "French", "fr", "fre" -> "fra")
  public func normalize(_ raw: String?) -> String {
    guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty else {
      return "und"
    }

    if raw == "pt-br" || raw == "pt_br" || raw == "brazilian" || raw == "pb" || raw == "pob" {
      return "pob"
    }

    if let match = languages.first(where: { $0.code == raw || $0.iso639_2b == raw }) {
      return match.code
    }
    if let match = languages.first(where: { $0.iso639_1 == raw }) {
      return match.code
    }
    if let match = languages.first(where: { $0.name.lowercased() == raw || $0.nativeName.lowercased() == raw }) {
      return match.code
    }

    return raw
  }

  /// Converts to 2-letter ISO 639-1 code
  public func toIso639_1(_ code: String) -> String {
    let norm = normalize(code)
    if let match = languages.first(where: { $0.code == norm }) {
      return match.iso639_1
    }
    return String(norm.prefix(2))
  }

  public func language(for codeOrName: String) -> SubtitleLanguage? {
    let norm = normalize(codeOrName)
    return languages.first(where: { $0.code == norm })
  }

  /// STRICT LANGUAGE FILTER:
  /// Discards any subtitle whose language does not match targetLanguage, unless allowFallback is true and zero items matched.
  public func filterStrict(results: [SubtitleResult], targetLanguage: String, allowFallback: Bool = false) -> [SubtitleResult] {
    let targetNorm = normalize(targetLanguage)

    let matched = results.filter { sub in
      let subNorm = normalize(sub.languageCode.isEmpty ? sub.language : sub.languageCode)
      return subNorm == targetNorm
    }

    if !matched.isEmpty {
      return matched
    }

    if allowFallback {
      return results
    }

    return []
  }
}
