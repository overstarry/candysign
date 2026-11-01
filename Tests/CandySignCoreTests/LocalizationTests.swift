import Foundation
import Testing

@testable import CandySignCore

@Test func choosesSimplifiedChineseAndEnglishFallback() {
  #expect(L10n.preferredLanguage(for: ["zh-Hans-CN"]) == "zh-Hans")
  #expect(L10n.preferredLanguage(for: ["en-US"]) == "en")
  #expect(L10n.preferredLanguage(for: ["de-DE"]) == "en")
  #expect(L10n.text("Connected", language: "zh-Hans") == "\u{5DF2}\u{8FDE}\u{63A5}")
  #expect(L10n.text("Connected", language: "en") == "Connected")
  #expect(L10n.text("Future device protocol", language: "zh-Hans") == "Future device protocol")
}

@Test func translationsHaveMatchingKeysAndFormatArguments() throws {
  func strings(_ language: String) throws -> [String: String] {
    let url = try #require(
      Bundle.module.url(
        forResource: "Localizable", withExtension: "strings", subdirectory: nil,
        localization: language))
    let value = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
    return try #require(value as? [String: String])
  }
  let english = try strings("en")
  let chinese = try strings("zh-Hans")
  #expect(english.count >= 70)
  #expect(Set(english.keys) == Set(chinese.keys))
  let formatPattern = try NSRegularExpression(pattern: "%(?:@|ld|d)")
  func placeholders(_ value: String) -> [String] {
    formatPattern.matches(in: value, range: NSRange(value.startIndex..., in: value))
      .map { (value as NSString).substring(with: $0.range) }
  }
  for (key, value) in english {
    let translated = try #require(chinese[key])
    #expect(!translated.isEmpty)
    #expect(placeholders(value) == placeholders(translated))
    #expect(L10n.text(key, language: "zh-Hans") == translated)
    #expect(L10n.text(key, language: "en") == value)
  }
}

@Test func localizedFormatsKeepNumbersAndPortNames() {
  let status = L10n.format(
    "The server returned HTTP %ld. Check the MCP address or try again.", 401, language: "zh-Hans")
  #expect(status.contains("401"))
  #expect(!status.contains("%"))
  let port = L10n.format("Port %@, %@, %@", "C1", "Charging", "12.5 W", language: "zh-Hans")
  #expect(port.contains("C1") && port.contains("12.5 W"))
  #expect(!port.contains("%@"))
  #expect(L10n.format("%ld charging", 2, language: "en") == "2 charging")
  #expect(
    L10n.format("The MCP request failed (%ld). Try refreshing.", 4_294_967_296, language: "en")
      .contains("4294967296"))
}
