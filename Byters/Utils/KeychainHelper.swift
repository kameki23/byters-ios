import Foundation
import Security
import os.log

enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain save failed: \(SecCopyErrorMessageString(status, nil) as String? ?? "status \(status)")"
        case .loadFailed(let status):
            return "Keychain load failed: \(SecCopyErrorMessageString(status, nil) as String? ?? "status \(status)")"
        case .deleteFailed(let status):
            return "Keychain delete failed: \(SecCopyErrorMessageString(status, nil) as String? ?? "status \(status)")"
        case .encodingFailed:
            return "Failed to encode value for Keychain storage"
        }
    }
}

enum KeychainHelper {
    private static let service = "jp.byters.app"
    private static let logger = Logger(subsystem: "jp.byters.app", category: "Keychain")

    @discardableResult
    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            logger.error("Failed to encode value for key '\(key)'")
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            logger.error("Failed to save key '\(key)': \(SecCopyErrorMessageString(status, nil) as String? ?? "unknown", privacy: .public)")
        }
        return status == errSecSuccess
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status != errSecSuccess && status != errSecItemNotFound {
            logger.warning("Failed to load key '\(key)': \(SecCopyErrorMessageString(status, nil) as String? ?? "unknown", privacy: .public)")
        }

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.error("Failed to delete key '\(key)': \(SecCopyErrorMessageString(status, nil) as String? ?? "unknown", privacy: .public)")
        }
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
