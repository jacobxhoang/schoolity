import Foundation
import Security

struct SavedSession: Codable {
    let value: String
    let expires: Date
    var isValid: Bool { !value.isEmpty && expires > Date() }
}

enum SessionVault {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.schoolity.app.session",
         kSecAttrAccount as String: "schoolity_session"]
    }

    static func load() -> SavedSession? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = try? JSONDecoder().decode(SavedSession.self, from: data), token.isValid else { return nil }
        return token
    }

    static func save(_ token: SavedSession) throws {
        let data = try JSONEncoder().encode(token)
        let values: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(values) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw PortalFailure.message("Couldn’t save your sign-in on this iPhone. Try again.") }
    }

    static func clear() { SecItemDelete(query as CFDictionary) }
}
