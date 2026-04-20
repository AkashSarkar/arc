import Foundation
import Security

protocol APIKeyProviding {
    func apiKey(for account: String) throws -> String?
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
}
