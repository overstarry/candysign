import Foundation

public enum L10n {
  public static let supportedLanguages = ["en", "zh-Hans"]
  public static let language = preferredLanguage(for: Locale.preferredLanguages)

  public static func preferredLanguage(for preferences: [String]) -> String {
    Bundle.preferredLocalizations(from: supportedLanguages, forPreferences: preferences).first
      ?? "en"
  }

  public static func text(_ key: String, language: String = language) -> String {
    guard let path = Bundle.module.path(forResource: language, ofType: "lproj"),
      let bundle = Bundle(path: path)
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
