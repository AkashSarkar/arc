import Foundation
import Security

protocol APIKeyProviding {
    func apiKey(for account: String) throws -> String?
    func saveAPIKey(_ apiKey: String, for account: String) throws
    func deleteAPIKey(for account: String) throws
}

struct KeychainStore: APIKeyProviding {
    enum KeychainError: LocalizedError {
        case unexpectedData
        case unhandledStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .unexpectedData:
                return "Unexpected data found in keychain."
            case let .unhandledStatus(status):
                return "Keychain operation failed with status \(status)."
            }
        }
    }

    func apiKey(for account: String) throws -> String? {
        let service = Bundle.main.bundleIdentifier ?? "Arc"
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }

        guard
            let data = item as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            throw KeychainError.unexpectedData
        }

        return value
    }

    func saveAPIKey(_ apiKey: String, for account: String) throws {
        let service = Bundle.main.bundleIdentifier ?? "Arc"
        let encodedValue = Data(apiKey.utf8)
        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: encodedValue
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
            ]
            let updates: [CFString: Any] = [
                kSecValueData: encodedValue
            ]

            let updateStatus = SecItemUpdate(query as CFDictionary, updates as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unhandledStatus(updateStatus)
            }

            return
        }

        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    func deleteAPIKey(for account: String) throws {
        let service = Bundle.main.bundleIdentifier ?? "Arc"
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }
}
