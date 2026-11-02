import Foundation
import Security

/// Small Keychain wrapper for provider tokens. Keys never enter UserDefaults,
/// logs or the app bundle.
@MainActor
public enum SportsKeychain {
    #if DEBUG
    /// Development builds must not touch the release Keychain item. Besides avoiding a
    /// password prompt on every rebuild, this keeps a debug key from replacing the real one.
    private static let service = "com.j4yop.arrowslit.sports.dev"
    #else
    private static let service = "com.j4yop.arrowslit.sports"
    #endif

    public static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    public static func save(_ value: String, account: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            delete(account: account)
            return
        }
        let data = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw SportsKeychainError.saveFailed(updateStatus)
        }
        var insert = query
        insert.merge(attributes) { _, new in new }
        let insertStatus = SecItemAdd(insert as CFDictionary, nil)
        guard insertStatus == errSecSuccess else {
            throw SportsKeychainError.saveFailed(insertStatus)
        }
    }

    public static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

public enum SportsKeychainError: LocalizedError {
    case saveFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            "Could not save the key to Keychain (\(status))."
        }
    }
}
