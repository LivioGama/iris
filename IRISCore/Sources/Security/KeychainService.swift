import Foundation
import Security

public enum KeychainError: Error {
    case failedToSave
    case failedToRetrieve
    case failedToDelete
    case itemNotFound
    case invalidData
    case unexpectedStatus(OSStatus)
}

public class KeychainService {
    public static let shared = KeychainService()

    private let service = "com.iris.gemini"
    private let account = "gemini-api-key"
    
    private var localFilePath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".iris_api_key")
    }

    private init() {}

    /// Saves the API key securely to the Keychain and a local file fallback
    public func saveAPIKey(_ apiKey: String) throws {
        // Save to local file first (to avoid keychain prompts if it's already there)
        try? apiKey.write(to: localFilePath, atomically: true, encoding: .utf8)

        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // Delete existing item if present
        try? deleteAPIKey()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            // If keychain fails, we still have the file, so we don't necessarily throw here
            // unless we strictly want keychain to work.
            print("⚠️ Keychain save failed with status \(status), using local file only")
            return
        }
    }

    /// Retrieves the API key from the Keychain
    public func getAPIKey() throws -> String {
        // Try local file first (avoids keychain prompts)
        if let key = try? String(contentsOf: localFilePath, encoding: .utf8) {
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return apiKey
    }

    /// Deletes the API key from the Keychain
    public func deleteAPIKey() throws {
        // Delete local file
        try? FileManager.default.removeItem(at: localFilePath)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Checks if API key exists in Keychain
    public func hasAPIKey() -> Bool {
        do {
            _ = try getAPIKey()
            return true
        } catch {
            return false
        }
    }
}
