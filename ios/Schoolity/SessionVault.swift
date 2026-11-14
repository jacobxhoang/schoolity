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

struct KeychainStorageFailure: LocalizedError {
    let status: OSStatus
    var errorDescription: String? { "Couldn’t access your saved sign-in on this iPhone. Try again." }
}

@MainActor
enum SessionVault {
    private static let store = KeychainSessionStore(service: "com.schoolity.app.session")
    static func info() -> SavedSessionInfo? { store.info() }
    static func load(context: LAContext?) throws -> SavedSession? { try store.load(context: context) }
    static func save(_ token: SavedSession, requiresUnlock: Bool) throws { try store.save(token, requiresUnlock: requiresUnlock) }
    static func clear() { store.clear() }
}

struct KeychainSessionStore: Sendable {
    let service: String
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: "schoolity_session"]
    }
    private var metadataQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: "schoolity_session_info"]
    }

    func info() -> SavedSessionInfo? {
        // Discover saved sign-in without touching the user-presence item. This
        // separate device-only entry contains flags/expiry, never credentials.
        var metadataLookup = metadataQuery
        metadataLookup[kSecReturnData as String] = true
        metadataLookup[kSecMatchLimit as String] = kSecMatchLimitOne
        let discoveryContext = LAContext()
        discoveryContext.interactionNotAllowed = true
        metadataLookup[kSecUseAuthenticationContext as String] = discoveryContext
        var metadataResult: CFTypeRef?
        let metadataStatus = SecItemCopyMatching(metadataLookup as CFDictionary, &metadataResult)
        if metadataStatus == errSecSuccess, let data = metadataResult as? Data,
           let info = try? JSONDecoder().decode(SavedSessionInfo.self, from: data) { return info }

        // Older builds kept these flags on the protected item itself. An auth
        // restriction is evidence of a saved entry, not permission to erase it.
        var lookup = query
        lookup[kSecReturnAttributes as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        lookup[kSecUseAuthenticationContext as String] = discoveryContext
        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecSuccess, let attributes = result as? [String: Any],
           let data = attributes[kSecAttrGeneric as String] as? Data,
           var info = try? JSONDecoder().decode(SavedSessionInfo.self, from: data) {
            info.legacy = true
            return info
        }
        return Self.discoveryFallback(itemStatus: status, metadataStatus: metadataStatus)
    }

    static func discoveryFallback(itemStatus: OSStatus, metadataStatus: OSStatus) -> SavedSessionInfo? {
        guard itemStatus != errSecItemNotFound || metadataStatus != errSecItemNotFound else { return nil }
        // Unknown metadata always requires authentication. Only a confirmed
        // missing entry is a missing account; transient errors remain retryable.
        return SavedSessionInfo(expires: .distantFuture, requiresUnlock: true, legacy: true)
    }

    func load(context: LAContext?) throws -> SavedSession? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        let readContext = context ?? LAContext()
        // The caller already authenticated. Reuse that context without allowing
        // a second hidden Keychain prompt, or any unauthenticated secret read.
        readContext.interactionNotAllowed = true
        lookup[kSecUseAuthenticationContext as String] = readContext
        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainStorageFailure(status: status) }
        guard let data = result as? Data,
              let token = try? JSONDecoder().decode(SavedSession.self, from: data), token.isValid || token.canRenew else { clear(); return nil }
        return token
    }

    func save(_ token: SavedSession, requiresUnlock: Bool) throws {
        // Credentials are never saved in the passcode-free fallback entry.
        guard requiresUnlock || !token.canRenew else { throw DeviceUnlockFailure.unavailable }
        let data = try JSONEncoder().encode(token)
        var values = query
        values[kSecValueData as String] = data
        let metadata = try JSONEncoder().encode(SavedSessionInfo(expires: token.expires, requiresUnlock: requiresUnlock, canRenew: token.canRenew))
        values[kSecAttrGeneric as String] = metadata
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
        guard status == errSecSuccess else { throw KeychainStorageFailure(status: status) }
        try saveMetadata(metadata)
    }

    private func saveMetadata(_ data: Data) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(metadataQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainStorageFailure(status: updateStatus)
        }
        let values = metadataQuery.merging(attributes) { _, new in new }
        let addStatus = SecItemAdd(values as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainStorageFailure(status: addStatus)
        }
    }

    func clear() {
        SecItemDelete(query as CFDictionary)
        SecItemDelete(metadataQuery as CFDictionary)
    }
}
