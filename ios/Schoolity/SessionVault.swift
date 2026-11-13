import Foundation
import Security
import LocalAuthentication

struct SavedSession: Codable {
    let value: String
    let expires: Date
    var username: String?
    var password: String?
    var isValid: Bool { !value.isEmpty && expires > Date() }
    var canRenew: Bool { !(username ?? "").isEmpty && !(password ?? "").isEmpty }
}

// Non-secret metadata lets the app show an unlock screen without retrieving
// the protected cookie. Legacy entries are upgraded after local authentication.
struct SavedSessionInfo: Codable {
    let expires: Date
    let requiresUnlock: Bool
    var legacy: Bool = false
    var canRenew: Bool?
    var isValid: Bool { expires > Date() || canRenew == true }
}

enum SessionVault {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.schoolity.app.session",
         kSecAttrAccount as String: "schoolity_session"]
    }

    static func info() -> SavedSessionInfo? {
        var lookup = query
        lookup[kSecReturnAttributes as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        lookup[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
        var result: CFTypeRef?
        guard SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess,
              let attributes = result as? [String: Any] else { return nil }
        if let data = attributes[kSecAttrGeneric as String] as? Data,
           let info = try? JSONDecoder().decode(SavedSessionInfo.self, from: data) { return info }
        return SavedSessionInfo(expires: .distantFuture, requiresUnlock: false, legacy: true)
    }

    static func load(context: LAContext?) throws -> SavedSession? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        lookup[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
        if let context { lookup[kSecUseAuthenticationContext as String] = context }
        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw DeviceUnlockFailure.failed }
        guard let data = result as? Data,
              let token = try? JSONDecoder().decode(SavedSession.self, from: data), token.isValid || token.canRenew else { clear(); return nil }
        return token
    }

    static func save(_ token: SavedSession, requiresUnlock: Bool) throws {
        // Credentials are never saved in the passcode-free fallback entry.
        guard requiresUnlock || !token.canRenew else { throw DeviceUnlockFailure.unavailable }
        let data = try JSONEncoder().encode(token)
        var values = query
        values[kSecValueData as String] = data
        values[kSecAttrGeneric as String] = try JSONEncoder().encode(SavedSessionInfo(expires: token.expires, requiresUnlock: requiresUnlock, canRenew: token.canRenew))
        if requiresUnlock {
            var error: Unmanaged<CFError>?
            guard let control = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .userPresence, &error) else {
                throw DeviceUnlockFailure.unavailable
            }
            values[kSecAttrAccessControl as String] = control
        } else {
            values[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
        // Replacing the entry also upgrades an old unprotected cookie's ACL.
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(values as CFDictionary, nil)
        guard status == errSecSuccess else { throw PortalFailure.message("Couldn’t save your sign-in on this iPhone. Try again.") }
    }

    static func clear() { SecItemDelete(query as CFDictionary) }
}
