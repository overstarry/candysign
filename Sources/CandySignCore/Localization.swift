import Foundation

public enum L10n {
  public static let supportedLanguages = ["en", "zh-Hans"]
  public static let language = preferredLanguage(for: Locale.preferredLanguages)

  public static func preferredLanguage(for preferences: [String]) -> String {
    Bundle.preferredLocalizations(from: supportedLanguages, forPreferences: preferences).first
      ?? "en"
  }

  public static func text(_ key: String, language: String = language) -> String {
    // Matched by localization, not folder name: some SwiftPM versions write "zh-hans.lproj".
    guard
      let strings = Bundle.module.url(
        forResource: "Localizable", withExtension: "strings", subdirectory: nil,
        localization: language),
      let bundle = Bundle(url: strings.deletingLastPathComponent())
    else { return key }
    return bundle.localizedString(forKey: key, value: key, table: nil)
  }

  public static func format(_ key: String, _ arguments: CVarArg..., language: String = language)
    -> String
  {
    // No locale: status and error codes must not gain grouping separators.
    String(format: text(key, language: language), arguments: arguments)
  }
}
