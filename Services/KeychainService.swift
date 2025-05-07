import Foundation
import Security

struct KeychainService {
    // Generic function to save data
    static func saveData(data: Data, service: String, account: String) -> OSStatus {
        // Ensure service and account are not empty, as Keychain requires them.
        guard !service.isEmpty, !account.isEmpty else {
            // Consider logging this error or throwing a custom error
            return errSecParam // Or another appropriate error code
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        // Delete existing item first to ensure we replace it cleanly.
        SecItemDelete(query as CFDictionary)

        // Add the new item.
        return SecItemAdd(query as CFDictionary, nil)
    }

    // Generic function to load data
    static func loadData(service: String, account: String) -> Data? {
        // Ensure service and account are not empty.
        guard !service.isEmpty, !account.isEmpty else {
             // Consider logging this error
            return nil
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne // Ensure we only get one item back
        ]

        var dataTypeRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess {
            // Successfully retrieved data.
            return dataTypeRef as? Data
        } else if status == errSecItemNotFound {
            // Item not found is a common case, not necessarily an error.
            // Consider logging this occurrence if helpful for debugging.
            return nil
        } else {
            // An actual error occurred. Log it for debugging.
            // Consider logging the specific OSStatus code for more details.
            // os_log("Keychain load error: Status %{public}ld for service %{public}@, account %{public}@", log: .default, type: .error, status, service, account)
            return nil
        }
    }

    // Generic function to delete data
    static func deleteData(service: String, account: String) -> OSStatus {
         // Ensure service and account are not empty.
        guard !service.isEmpty, !account.isEmpty else {
             // Consider logging this error or throwing a custom error
            return errSecParam
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        // Return the status of the delete operation.
        // errSecItemNotFound is also a possible 'success' in the sense that the item is gone.
        return SecItemDelete(query as CFDictionary)
    }
}

// Helper extension Data -> String (as provided in TASKS.md)
// Consider adding a corresponding String -> Data helper if needed frequently.
extension Data {
    func toString() -> String? {
        return String(data: self, encoding: .utf8)
    }
}

// Optional: Helper extension String -> Data
extension String {
    func toData() -> Data? {
        return self.data(using: .utf8)
    }
} 