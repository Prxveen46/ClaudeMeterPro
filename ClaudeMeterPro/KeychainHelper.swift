import Foundation
import Security

enum KeychainHelper {
    private static let service = "com.claudemeterpro"
    private static let account = "claude-session-key"

    static func save(apiKey: String) -> Bool {
        guard let data = apiKey.data(using: .utf8) else { return false }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            // Fallback: try loading from old keychain identifier (migration)
            return loadLegacy()
        }
        return String(data: data, encoding: .utf8)
    }

    static func delete() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)

        // Also delete legacy entry
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.claudemeterpro.apikey",
            kSecAttrAccount as String: "anthropic-api-key"
        ]
        SecItemDelete(legacyQuery as CFDictionary)

        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Returns masked version like "••••••1AAA"
    static func maskedKey() -> String? {
        guard let key = load(), key.count > 4 else { return nil }
        let suffix = String(key.suffix(4))
        return "••••••\(suffix)"
    }

    // MARK: - Legacy Migration

    private static func loadLegacy() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.claudemeterpro.apikey",
            kSecAttrAccount as String: "anthropic-api-key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        // Migrate to new identifier
        _ = save(apiKey: key)
        return key
    }
}
