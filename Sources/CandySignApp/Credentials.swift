import CandySignCore
import Foundation
import Security

enum CredentialError: Error, LocalizedError {
  case keychain(OSStatus)
  var errorDescription: String? {
    L10n.text("Could not access Keychain. Unlock your login keychain and try again.")
  }
}

enum Credentials {
  private static let identity: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.candysign.CandySign",
    kSecAttrAccount as String: "mcp-endpoint",
  ]

  static func load() throws -> URL? {
    var query = identity
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = result as? Data,
      let value = String(data: data, encoding: .utf8)
    else {
      throw CredentialError.keychain(status)
    }
    return try MCPClient.validatedURL(value)
  }

  static func save(_ endpoint: URL) throws {
    let value = Data(endpoint.absoluteString.utf8)
    let changes: [String: Any] = [kSecValueData as String: value]
    var status = SecItemUpdate(identity as CFDictionary, changes as CFDictionary)
    if status == errSecItemNotFound {
      var item = identity
      item[kSecValueData as String] = value
      item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
      status = SecItemAdd(item as CFDictionary, nil)
    }
    guard status == errSecSuccess else { throw CredentialError.keychain(status) }
  }
}
